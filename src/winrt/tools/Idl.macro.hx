package winrt.tools;

import haxe.macro.Type;
import haxe.macro.Context;
import sys.io.File;

var idlFile = "RuntimeClasses.idl";

function setup() {
    Context.onAfterTyping(generate);
}

function generate(modules:Array<ModuleType>) {
    final fo = File.write(idlFile);
    final writer = new IdlWriter(fo);
    for (mod in modules) {
        switch (mod) {
            case TClassDecl(_.get() => c) if (c.meta.has(Meta.RuntimeClass)):
                writer.writeClass(c);
            default:
        }
    }
    fo.close();
}