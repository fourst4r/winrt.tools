package winrt.tools;

import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.TypeTools;

#if !macro
@:genericBuild(winrt.tools.RuntimeClass.Builder.build())
interface RuntimeClass<T, TBase: winrt.windows.foundation.IInspectable> {}
#end


class Builder {

    static var _inited = false;

    static function writeIdlFiles(modules:Array<ModuleType>) {
        modules = modules.filter(isRuntimeClass);
        for (mod in modules) {
            switch (mod) {
                case TClassDecl(_.get() => c):
                    final fo = File.write(c.name + ".idl");
                    final writer = new IdlWriter(fo);
                    writer.writeClass(c);
                    fo.close();
                default:
                    throw "Unsupported IDL module: "+mod;
            }
        }
    }

    static function isRuntimeClass(module) {
        return switch (module) {
            case TClassDecl(_.get() => c) if (c.meta.has(Meta.RuntimeClass)): true;
            default: false;
        }
    }

    public static function build() {
        #if macro

        if (!_inited) {
            Context.onAfterTyping(writeIdlFiles);
            _inited = true;
        }

        final type = Context.getLocalType();

        switch (type) {
            case TInst(_, [TInst(t_ref,_), TInst(_.get() => base,_)]):

                final t = t_ref.get();
                final name = t.name;
                final nameT = name + "T";
                final include = '${name}.g.h';
                
                // add meta for the IDL generator
                t.meta.add(Meta.RuntimeClass, [], t.pos);
                
                Context.defineType(mkRuntimeClassExtern(nameT, include, {pack: base.pack, name: base.name}));

                return TPath({
                    name: nameT,
                    params: [TPType(TypeTools.toComplexType(TInst(t_ref, [])))],
                    pack: []
                });

            default:
                throw "Invalid local type.";
        }
        #end
    }

    // Constructs an extern for the runtime class that is generated in C++ from the MIDL compiler,
    // i.e. it generates the `MainWindowT` from `class MainWindow extends MainWindowT<MainWindow>`.
    static function mkRuntimeClassExtern(nativeName:String, nativeInclude:String, base:TypePath) {
        #if macro
        var pos = Context.currentPos();
        var c = macro class $nativeName<T> extends $base {};
        c.isExtern = true;
        c.meta = [
            {name: ":include", params: [macro $v{'$nativeInclude'}], pos: pos},
            {name: ":nativeTypeCode", params: [macro $v{'$nativeName<{type0}>'}], pos: pos},
            {name: Meta.BaseT, pos: pos}
        ];
        return c;
        #end
    }
}