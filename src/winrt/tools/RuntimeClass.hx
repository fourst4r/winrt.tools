package winrt.tools;

import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.TypeTools;

#if !macro
@:genericBuild(winrt.tools.RuntimeClass.Builder.build())
interface RuntimeClass<T, TBase/*: winrt.windows.foundation.IInspectable*/> {}
#end


class Builder {

    static final IDL_FILENAME = "RuntimeClasses.idl";
    static var _inited = false;
    static var _runtimeClasses:Array<ClassType>;

    static function writeIdlFiles(modules:Array<ModuleType>) {
        #if macro

        modules = modules.filter(isRuntimeClass);

        // var tydef:TypeDefinition = {
        //     pack: t.pack.copy().concat(["implementation"]),
        //     name: t.name + "TYPEDEF",
        //     kind: TDAlias(TypeTools.toComplexType(TInst(t_ref, []))),
        //     pos: impl.pos,
        //     fields: [],
        // };
        // trace(tydef.name);
        // Context.defineType(tydef);


        final fo = File.write(IDL_FILENAME);
        for (mod in modules) {
            switch (mod) {
                case TClassDecl(_.get() => c):
                    final writer = new IdlWriter(fo);
                    writer.writeClass(c);
                default:
                    throw "Unsupported IDL module: "+mod;
            }
        }
        fo.close();

        #end
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
                final include = '../Generated Files/${name}.g.h';
                
                // add meta for the IDL generator
                t.meta.add(Meta.RuntimeClass, [], t.pos);
                trace(t.name);

                final impl = macro class $name {};
                $type(impl);
                $type(t);
                impl.fields = [];
                for (f in t.fields.get()) {
                    impl.fields.push({
                        name: f.name,
                        pos: f.pos,
                        kind: switch (f.kind) {
                            case FVar(read, write): null;
                            case FMethod(k): null;
                        },
                    });
                }
                impl.pack = t.pack.copy().concat(["implementation"]);
                // Context.defineType(impl);



                // Context.defineType(mkRuntimeClassImpl(name));
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

    static function mkRuntimeClassImpl(name:String) {
        #if macro
        final pos = Context.currentPos();
        final c = macro class $name {}
        #end
    }
    
    static function mkRuntimeClassFactoryImpl(name:String) {

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