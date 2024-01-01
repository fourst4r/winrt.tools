package winrt.tools;

import haxe.exceptions.NotImplementedException;
import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.TypeTools;
using StringTools;

#if !macro
@:genericBuild(winrt.tools.RuntimeClass.Builder.build())
interface RuntimeClass<T, TBase/*: winrt.windows.foundation.IInspectable*/> {}
#end


class Builder {

    static final IDL_FILENAME = "RuntimeClasses.idl";
    static var _inited = false;
    static var _runtimeClasses:Array<ClassType>;

    #if macro

    /**
     * Builds a Windows Runtime Class projection for this class.
     * @return Array<Field>
     */
    public static function buildRT():Array<Field> {

        Context.filterMessages(m -> {
            return switch (m) {
                case Warning(msg, pos) if (msg.startsWith("(WExternWithExpr)")): false;
                default: true;
            }
        });

        final fields = Context.getBuildFields();
        final pos = Context.currentPos();
        final cls = Context.getLocalClass()?.get();
        cls.meta.add(":haxe.warning", [macro $v{"-WExternWithExpr"}], pos);
        final className = cls.name;
        final classNameT = cls.name + "T";
        final classNameT2 = cls.name + "T";
        final externInclude = '../Generated Files/${cls.name}.g.h';
        final base:TypePath = @:privateAccess cls.superClass?.t.get().toTypePath(cls.superClass.params);

        final imports = Context.getLocalImports();
        // final imports = Context.getLocalImports().map(c -> c.path.map(p -> p.name).join("."));
        // trace("imports: "+imports);
        // final usings = Context.getLocalUsing().map(c -> {
        //     final c = c.get();
        //     return c.pack.join(".") + "." + c.name;
        // });
        
        // TODO: handle module-level usings (and probably imports?)
        final usings = @:privateAccess Context.getLocalUsing().map(c -> c.get().toTypePath([]));

        trace("currentModule: "+Context.getLocalModule());
        trace("usings: "+usings);
        

        final projectionPack = cls.pack.copy();
        projectionPack.unshift("winrt");
        final projectionFqn = projectionPack.join("::") + '::${cls.name}';
        cls.meta.add(":native", [macro $v{projectionFqn}], pos);
        cls.exclude();

        var pack = [];
        pack.push("winrt");
        pack = pack.concat(cls.pack);
        pack.push("implementation");

        // Define the `implementation` type.
        final externClsT:TypeDefinition = macro class $classNameT<T> extends $base {};
        externClsT.isExtern = true;
        externClsT.pack = pack;
        externClsT.meta.push({name: ":include", params: [macro $v{externInclude}], pos: pos});
        externClsT.meta.push({name: ":nativeTypeCode", params: [macro $v{'${classNameT}<{type0}>'}], pos: pos});
        // Context.withImports(imports, usings, () -> Context.defineType(externClsT));
        Context.defineType(externClsT);
        
        final classPathT:TypePath = {name: externClsT.name, pack: externClsT.pack};
        final classImplComplexType = TPath({name: cls.name, pack: pack});
        final implCls:TypeDefinition = macro class $className extends $classPathT<$classImplComplexType> {};
        implCls.pack = pack;
        implCls.fields = fields;
        implCls.meta.push({name: ":keep", params: null, pos: pos});
        implCls.meta.push({name: ":valueType", params: null, pos: pos});
        implCls.meta.push({name: ":cppFileCode", params: [macro $v{'
#if __has_include("${cls.name}.g.cpp")
    #include "${cls.name}.g.cpp"
#endif
'}], pos: pos});
        // Context.withImports(imports, usings, () -> {
        //     trace("ctx imports: "+Context.getLocalImports().map(c -> c.path.map(p -> p.name).join(".")));
        //     Context.defineType(implCls);
        // });
        // Context.defineType(implCls);
        final module = implCls.pack.join(".") + "." + implCls.name;
        Context.defineModule(module, [implCls], imports, usings);

        // Define the `factory_implementation` type.
        var pack = [];
        pack.push("winrt");
        pack = pack.concat(cls.pack);
        pack.push("factory_implementation");

        final externClsT2:TypeDefinition = macro class $classNameT2<T, U> extends $base {}; // TODO: does it actually extend base?
        externClsT2.isExtern = true;
        externClsT2.pack = pack;
        externClsT2.meta.push({name: ":valueType", params: null, pos: pos});
        externClsT2.meta.push({name: ":include", params: [macro $v{externInclude}], pos: pos});
        externClsT2.meta.push({name: ":filename", params: [macro $v{'winrt_myApp_implementation_${cls.name}'}], pos: pos});
        externClsT2.meta.push({name: ":nativeTypeCode", params: [macro $v{'${classNameT2}<{type0}, {type1}>'}], pos: pos});
        // Context.withImports(imports, usings, () -> Context.defineType(externClsT2));
        Context.defineType(externClsT2);

        final classFacComplexType = TPath({name: cls.name, pack: pack});
        final classPathT2:TypePath = {name: externClsT2.name, pack: externClsT2.pack};
        final facCls:TypeDefinition = macro class $className extends $classPathT2<$classFacComplexType, $classImplComplexType> {
            public function new() {}
        };

        facCls.meta.push({name: ":keep", params: null, pos: pos});
        facCls.meta.push({name: ":valueType", params: null, pos: pos});
        facCls.meta.push({name: ":filename", params: [macro $v{'winrt_myApp_implementation_${cls.name}'}], pos: pos});
        facCls.pack = pack;

        // Context.withImports(imports, usings, () -> {
        //     trace("ctx imports: "+Context.getLocalImports().map(c -> c.path.map(p -> p.name).join(".")));
        //     Context.defineType(facCls);
        // });
        // Context.defineType(facCls);
        final module = facCls.pack.join(".") + "." + implCls.name;
        Context.defineModule(module, [facCls], imports, usings);


        // Extern-ify the user-defined class. 
        // cls.exclude();
        cls.isExtern = true;
        // return fields.map(stripFieldExpr);
        return fields;
    }

    static function stripFieldExpr(f:Field):Field {
        f.kind = switch (f.kind) {
            case FFun(fun):
                fun.expr = null;
                FFun(fun);
            case kind:
                kind;
        }
        return f;
    }

    static function writeIdlFiles(modules:Array<ModuleType>) {

        modules = modules.filter(isRuntimeClass);

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

      
    }

    #end

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
                
                // Step 1:
                // add meta for the IDL generator
                t.meta.add(Meta.RuntimeClass, [], t.pos);
                trace(t.name);
                // t.exclude();

                // Step 2:
                final impl = macro class $name {};
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
                trace('${t.name} fields:');
                for (f in t.fields.get()) {
                    trace('${f.name}=${f.expr()}');
                }

                var pack = [];
                pack.push("winrt");
                pack = pack.concat(t.pack.copy());
                pack.push("implementation");
                
                // Context.defineType(impl);

                // Step 3:
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