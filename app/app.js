var EXEC = "luna://org.webosbrew.hbchannel.service/exec";
var script = decodeURIComponent(location.pathname.replace(/\/[^\/]*$/, "")) + "/clean-home/clean-home.sh";
var bridges = [];
var tv = {};
var busy = false;

function $(id) { return document.getElementById(id); }

function exec(args, done) {
    var bridge = new PalmServiceBridge();
    bridges.push(bridge);
    bridge.onservicecallback = function (message) {
        bridges.splice(bridges.indexOf(bridge), 1);
        var response;
        try { response = JSON.parse(message); } catch (e) { response = { returnValue: false, errorText: String(message) }; }
        var out = ((response.stdoutString || "") + (response.stderrString || "")).replace(/\s+$/, "");
        if (!out && !response.returnValue) out = response.errorText || "The Homebrew Channel did not answer. Clean Home needs a rooted TV with the Homebrew Channel.";
        done(out, response.returnValue === true);
    };
    bridge.call(EXEC, JSON.stringify({ command: "sh '" + script + "' " + args + " 2>&1" }));
}

function setText(id, text, cls) {
    $(id).textContent = text;
    $(id).className = cls || "";
}

function show(id, visible, label) {
    $(id).hidden = !visible;
    if (label) $(id).textContent = label;
}

function time(seconds) {
    return new Date(seconds * 1000).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function render() {
    var mounted = tv.state === "mounted";
    var trial = tv.trial ? parseInt(tv.trial.replace(/\D/g, ""), 10) : 0;
    var bootHere = tv.boot === "enabled";
    var bootElsewhere = tv.boot && tv.boot.indexOf("from another copy") >= 0;
    var outdated = tv.view === "outdated";

    var state = mounted ? "Clean Home" : "Stock Home";
    if (trial) state += ", back to stock at " + time(trial);
    if (outdated) state += " (an update is ready)";
    setText("state", state, mounted ? "good" : "");
    if (bootHere) setText("boot", "Clean Home", "good");
    else if (bootElsewhere) setText("boot", "Clean Home, " + tv.boot.replace(/^enabled /, ""), "warn");
    else setText("boot", "Stock Home");
    if (tv.firmware === "compatible") setText("firmware", "Compatible (" + tv.tv + ")", "good");
    else if (tv.firmware === "changed") setText("firmware", "Updated since you turned Clean Home on, so stock Home is back. Turn it on again to use it.", "warn");
    else setText("firmware", "Not compatible (" + tv.tv + "): " + tv.problem.join("; "), "warn");
    setText("app", tv.app === "hidden" ? "Hidden from Clean Home. Press 0 on the Home screen to open it." : "Shown on Clean Home");

    var usable = tv.firmware !== "incompatible";
    var on = mounted && bootHere && !outdated && tv.firmware === "compatible";
    show("trial", !mounted && usable);
    show("enable", !on && usable, bootHere && outdated ? "Apply update" : "Turn on");
    show("disable", mounted || bootHere || bootElsewhere, trial ? "Back to stock now" : "Turn off");
    show("hide", true, tv.app === "hidden" ? "Show this app" : "Hide this app");

    if (!document.activeElement || document.activeElement.hidden || document.activeElement.tagName !== "BUTTON") visibleButtons()[0].focus();
}

function refresh() {
    exec("status", function (out) {
        var s = { problem: [] };
        out.split("\n").forEach(function (line) {
            var i = line.indexOf(": ");
            if (i < 1) return;
            if (line.slice(0, i) === "problem") s.problem.push(line.slice(i + 2));
            else s[line.slice(0, i)] = line.slice(i + 2);
        });
        if (!s.state) {
            ["state", "boot", "firmware", "app"].forEach(function (id) { setText(id, "Unknown", "warn"); });
            $("output").textContent = out;
            return;
        }
        tv = s;
        render();
    });
}

function run(args, message) {
    if (busy) return;
    busy = true;
    $("output").textContent = "Working…";
    exec(args, function (out, ok) {
        busy = false;
        $("output").textContent = ok ? message : out;
        refresh();
    });
}

$("trial").onclick = function () {
    run("trial 300", "Press Home to see it. It goes back to stock at " + time(Date.now() / 1000 + 300) + " unless you turn it on.");
};
$("enable").onclick = function () {
    run("enable", "Clean Home is on, now and after every restart. Press Home to see it.\n\n" +
        "If it works well, please add your TV to the tested list: github.com/kiri11/webos-clean-home");
};
$("disable").onclick = function () { run("disable", "Stock Home is back."); };
$("hide").onclick = function () {
    if (tv.app === "hidden") run("show-app", "This app shows on Clean Home again.");
    else run("hide-app", "This app no longer shows on Clean Home. To open it again, press 0 on the Home screen. Stock Home always shows it.");
};

function visibleButtons() {
    return Array.prototype.filter.call(document.querySelectorAll("button"), function (b) { return !b.hidden; });
}

document.addEventListener("keydown", function (event) {
    var buttons = visibleButtons();
    var i = buttons.indexOf(document.activeElement);
    if (event.keyCode === 37 || event.keyCode === 39) {
        var next = i < 0 ? 0 : Math.max(0, Math.min(buttons.length - 1, i + (event.keyCode === 39 ? 1 : -1)));
        buttons[next].focus();
        event.preventDefault();
    } else if ((event.keyCode === 38 || event.keyCode === 40) && i < 0) {
        buttons[0].focus();
        event.preventDefault();
    } else if (event.keyCode === 461) {
        window.close();
    }
});

function reopen() {
    if (document.hidden) return;
    $("output").textContent = "";
    refresh();
}

document.addEventListener("webOSRelaunch", reopen);
document.addEventListener("visibilitychange", reopen);
refresh();
