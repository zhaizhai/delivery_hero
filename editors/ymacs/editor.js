var desktop = new DlDesktop({});
desktop.fullScreen();

var dlg = new DlDialog({ title: "Ymacs", resizable: false });
var javascript = window.JS_BUFFER = new Ymacs_Buffer({ name: "test.js" });


var message_handlers = {
    init: initialize,
};
window.addEventListener('message', function (e) {
    var data = e.data;
    var idx = data.indexOf(':');
    var prefix, mesg;
    if (idx === -1) {
        prefix = data; mesg = '';
    } else {
        prefix = data.slice(0, idx);
        mesg = data.slice(idx + 1);
    }

    var handler = message_handlers[prefix];
    if (handler != null) {
        var ret = handler(mesg);
        var ret_string = prefix + ':';
        if (ret != null)
            ret_string += ret;
        window.top.postMessage(ret_string, '*');
        return;
    }
}, false);


var initialized = false;
function initialize(initial_text) {
    if (initialized)
        throw new Error("Can't initialize twice!");
    console.log("Editor initialized");

    initialized = true;
    javascript.setCode(initial_text);

    javascript.cmd("javascript_dl_mode");
    javascript.setq("indent_level", 4);


    var empty = new Ymacs_Buffer({ name: "empty" });
    var ymacs = window.ymacs = new Ymacs({ buffers: [ javascript ] });
    ymacs.setColorTheme([ "dark", "y" ]);
    try {
        ymacs.getActiveBuffer().cmd("eval_file", ".ymacs");
    } catch(ex) {}


    var layout = new DlLayout({ parent: dlg });
    layout.packWidget(ymacs, { pos: "bottom", fill: "*" });
    dlg._focusedWidget = ymacs;
    dlg.setSize({ x: 800, y: 600 });
    try {
        dlg.maximize(true);
    } catch (e) {
        console.log("Not sure why this is an error!");
        console.log(e);
    }
    dlg.show(true);

    message_handlers['get-code'] = function() {
        return JS_BUFFER.getCode();
    };
}


