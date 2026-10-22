#!/bin/sh
# clean-home.sh status|check|mount|remount|rollback|trial SECONDS|keep|enable|disable|hide-app|show-app|boot|restart-home
SRC=$(cd "$(dirname "$0")" && pwd)
DATA=/media/developer/clean-home
BIN=/usr/bin/com.webos.app.home
QML=/usr/palm/applications/com.webos.app.home/qml
VIEWS=$QML/UserInterfaceLayer/Containers
STOCK=/tmp/clean-home-stock
LOG=$DATA/clean-home.log
APPROVED=$DATA/approved
CACHE=$DATA/check-cache
HOOK=/var/lib/webosbrew/init.d/60-clean-home

mkdir -p "$DATA"
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
is_mounted() { awk -v t="$1" '$5==t {f=1} END {exit !f}' /proc/self/mountinfo; }
mounted() { is_mounted "$VIEWS/MainView.qml"; }
targets() { for v in MainView.qml MainView_WEE.qml; do [ -f "$VIEWS/$v" ] && echo "$VIEWS/$v"; done; }

unmount_views() {
    for t in $(targets); do
        while is_mounted "$t"; do umount "$t" || return 1; done
    done
}

stock_dir() {
    if mounted; then
        is_mounted "$STOCK" || { mkdir -p "$STOCK" && mount --bind "$VIEWS" "$STOCK"; } || return 1
        echo "$STOCK"
    else
        echo "$VIEWS"
    fi
}

close_stock() {
    if is_mounted "$STOCK"; then umount "$STOCK" && rmdir "$STOCK"; fi
}

fingerprint() {
    d=$(stock_dir) || return 1
    wee=$(sha "$d/MainView_WEE.qml")
    echo "$(sha "$BIN") $(sha "$d/MainView.qml") ${wee:--}"
    close_stock
}

check() {
    view=$SRC/MainView.qml
    all=/tmp/clean-home-qml.txt
    find "$QML" -name '*.qml' ! -name 'MainView*.qml' -exec cat {} + > "$all"
    declared=" $(grep -oE '(property +[A-Za-z_.<>]+|signal|function) +[A-Za-z_]+' "$view" | awk '{print $NF}' | tr '\n' ' ') activeFocus forceActiveFocus focus visible state width height x y opacity enabled "
    bad=0
    for name in main hidden half sub editMenu; do
        grep -q "\"$name\"" "$all" || { echo "Home no longer has the $name state"; bad=1; }
    done
    for name in launchPointId largeIcon iconColor externalDeviceList hdmiPlugIn connected label updatedAppObject Key_webOS_Back; do
        grep -qw "$name" "$all" || { echo "Home no longer uses $name"; bad=1; }
    done
    grep -qE 'function launchApp\(([^,)]+,){4}[^,)]+\)' "$all" || { echo "Home's launchApp no longer takes five arguments"; bad=1; }
    grep -qE 'function moveLaunchPoint\([^,)]+,[^,)]+\)' "$all" || { echo "Home's moveLaunchPoint no longer takes two arguments"; bad=1; }
    for name in initialize styleSheet $(grep -oE 'mainView\.[A-Za-z_]+(\.[A-Za-z_]+)?' "$all" | sed 's/^mainView\.//; s/\./ /' | tr ' ' '\n' | sort -u); do
        case "$declared" in *" $name "*) ;; *) echo "Home uses mainView.$name, which the clean view does not have"; bad=1 ;; esac
    done
    used=$( { grep -oE '(uiController|systemProperties)\.[A-Za-z_]+' "$view" | sed 's/.*\.//'
              grep -oE '^ *on[A-Z][A-Za-z]*Changed' "$view" | sed 's/^ *on//; s/Changed$//' | awk '{print tolower(substr($0, 1, 1)) substr($0, 2)}'
              echo rootWindow launchApp moveLaunchPoint; } | tr ' ' '\n' | sort -u)
    for name in $used; do
        case "$declared" in *" $name "*) continue ;; esac
        grep -qw "$name" "$all" || { echo "Home no longer has $name"; bad=1; }
    done
    rm -f "$all"
    [ -f "$QML/UserInterfaceLayer/GlobalStyle.qml" ] || { echo "Home no longer has GlobalStyle.qml"; bad=1; }
    [ -d /usr/lib/qml/QtGraphicalEffects ] || [ -d /usr/lib/qt5/qml/QtGraphicalEffects ] || { echo "QtGraphicalEffects is missing"; bad=1; }
    [ $bad = 0 ] && echo "compatible"
    return $bad
}

cached_check() {
    key="$(fingerprint) $(sha "$SRC/MainView.qml")"
    if [ "$(sed -n 1p "$CACHE" 2>/dev/null)" = "$key" ]; then
        sed '1,2d' "$CACHE"
        return "$(sed -n 2p "$CACHE")"
    fi
    out=$(check)
    code=$?
    [ "$(fingerprint) $(sha "$SRC/MainView.qml")" = "$key" ] && printf '%s\n%s\n%s\n' "$key" "$code" "$out" > "$CACHE"
    echo "$out"
    return $code
}

restart_home() {
    [ ! -d /tmp/checkpoint/com.webos.app.home ] || touch /tmp/checkpoint/com.webos.app.home/invalid_img
    for p in /proc/[0-9]*; do
        [ "$(readlink "$p/exe" 2>/dev/null)" = "$BIN" ] || continue
        kill -TERM "${p##*/}"
    done
}

bind_view() {
    [ -s "$SRC/MainView.qml" ] || { echo "missing $SRC/MainView.qml"; return 1; }
    unmount_views || { echo "could not unmount the current view"; return 1; }
    for t in $(targets); do
        mount --bind "$SRC/MainView.qml" "$t" || { unmount_views; return 1; }
    done
    log "mounted $SRC/MainView.qml"
}

do_mount() {
    out=$(cached_check) || { log "refused: $out"; echo "$out"; return 1; }
    bind_view
}

do_rollback() {
    rm -f "$DATA/trial-active"
    unmount_views
    log "rolled back"
    restart_home
}

info() {
    luna-send -n 1 luna://com.webos.service.tv.systemproperty/getSystemInfo '{"keys":["modelName","firmwareVersion","sdkVersion"]}' 2>/dev/null |
        sed 's/.*"modelName":"\([^"]*\)".*"firmwareVersion":"\([^"]*\)".*"sdkVersion":"\([^"]*\)".*/\1, firmware \2, webOS \3/'
}

case "$1" in
    status)
        if mounted; then
            echo "state: mounted"
            if [ "$(sha "$VIEWS/MainView.qml")" = "$(sha "$SRC/MainView.qml")" ]; then echo "view: current"; else echo "view: outdated"; fi
        else
            echo "state: stock"
        fi
        if [ ! -f "$HOOK" ]; then echo "boot: disabled"
        elif grep -q "$SRC/clean-home.sh" "$HOOK"; then echo "boot: enabled"
        else echo "boot: enabled from another copy ($(grep -o '/[^ ]*/clean-home.sh' "$HOOK" | head -1))"; fi
        [ -f "$DATA/trial-active" ] && echo "trial: rollback at $(cat "$DATA/trial-active")"
        if ! out=$(cached_check); then
            echo "firmware: incompatible"
            echo "$out" | sed 's/^/problem: /'
        elif [ -f "$HOOK" ] && [ "$(fingerprint)" != "$(cat "$APPROVED" 2>/dev/null)" ]; then
            echo "firmware: changed"
        else
            echo "firmware: compatible"
        fi
        echo "tv: $(info)"
        if [ -f "$DATA/hide-app" ]; then echo "app: hidden"; else echo "app: shown"; fi
        echo "source: $SRC"
        ;;
    check)
        check
        ;;
    mount|remount)
        do_mount && restart_home
        ;;
    rollback)
        do_rollback
        ;;
    trial)
        seconds=${2:-300}
        case "$seconds" in ''|*[!0-9]*) seconds=300 ;; esac
        end=$(( $(date +%s) + seconds ))
        echo "$end" > "$DATA/trial-active"
        setsid sh -c "while [ \$(date +%s) -lt $end ]; do [ \"\$(cat '$DATA/trial-active' 2>/dev/null)\" = $end ] || exit 0; sleep 2; done; [ \"\$(cat '$DATA/trial-active' 2>/dev/null)\" = $end ] && '$SRC/clean-home.sh' rollback" </dev/null >/dev/null 2>&1 &
        log "trial for ${seconds}s"
        if do_mount; then restart_home; echo "trial mounted, auto rollback in ${seconds}s"; else do_rollback; exit 1; fi
        ;;
    keep)
        rm -f "$DATA/trial-active"
        log "trial kept until reboot"
        echo "kept until reboot"
        ;;
    boot)
        log "boot"
        if [ "$(fingerprint)" = "$(cat "$APPROVED" 2>/dev/null)" ]; then
            bind_view && restart_home
        else
            log "firmware changed since enable, leaving stock Home: $(fingerprint)"
        fi
        exit 0
        ;;
    enable)
        rm -f "$DATA/trial-active"
        do_mount || exit 1
        fingerprint > "$APPROVED"
        mkdir -p "$(dirname "$HOOK")"
        printf '#!/bin/sh\n[ -x %s/clean-home.sh ] && %s/clean-home.sh boot\nexit 0\n' "$SRC" "$SRC" > "$HOOK"
        chmod 755 "$HOOK"
        log "enabled on $(cat "$APPROVED")"
        restart_home
        echo "enabled: $HOOK"
        ;;
    disable)
        rm -f "$HOOK" "$APPROVED"
        log "disabled"
        do_rollback
        echo "disabled"
        ;;
    hide-app)
        echo 1 > "$DATA/hide-app"
        log "app hidden"
        echo "hidden"
        ;;
    show-app)
        rm -f "$DATA/hide-app"
        log "app shown"
        echo "shown"
        ;;
    restart-home)
        restart_home
        ;;
    *)
        echo "usage: $0 status|check|mount|remount|rollback|trial SECONDS|keep|enable|disable|hide-app|show-app|boot|restart-home"
        exit 2
        ;;
esac
