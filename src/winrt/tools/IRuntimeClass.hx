package winrt.tools;

import sys.io.File;
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.TypeTools;
using StringTools;

function build() {
    #if macro
    
    final cls = Context.getLocalClass()?.get() ?? return null;
    final imports = Context.getLocalImports();
    final usings = @:privateAccess Context.getLocalUsing().map(c -> c.get().toTypePath([]));
    final fields = Context.getBuildFields();

    cls.meta.add(":extern", [], cls.pos);
    final nativeFqn = ["winrt"].concat(cls.pack).concat([cls.name]).join("::");
    cls.meta.add(":native", [macro $v{nativeFqn}], cls.pos);
    cls.meta.add(":unreflective", [], cls.pos);
    cls.meta.add(Meta.RuntimeClass, [], cls.pos);

    final className = cls.name;
    final classNameT = cls.name + "T";
    final externInclude = '../Generated Files/${cls.name}.g.h';
    final base:TypePath = @:privateAccess cls.superClass?.t.get().toTypePath(cls.superClass.params);

    var pack = [];
    pack.push("winrt");
    pack = pack.concat(cls.pack);
    pack.push("implementation");

    // -- Define the `implementation` type. --
    final externClsT:TypeDefinition = macro class $classNameT<T> extends $base {};
    externClsT.isExtern = true;
    externClsT.pack = pack;
    externClsT.meta.push({name: Meta.BaseT, pos: cls.pos});
    externClsT.meta.push({name: ":include", params: [macro $v{externInclude}], pos: cls.pos});
    externClsT.meta.push({name: ":nativeTypeCode", params: [macro $v{'${classNameT}<{type0}>'}], pos: cls.pos});
    externClsT.meta.push({name: ":unreflective", params:[], pos:cls.pos});
    
    final classImplComplexType = TPath({name: cls.name, pack: pack});
    final classPathT:TypePath = {name: externClsT.name, pack: externClsT.pack};
    final implCls:TypeDefinition = macro class $className extends $classPathT<$classImplComplexType> {};
    implCls.fields = fields;
    implCls.pack = pack;
    
    // forward relevant metas to the implementation
    function forward(meta) for (m in cls.meta.extract(meta)) implCls.meta.push(m);
    forward(":headerInclude");
    forward(":addInclude");
    forward(":filename");
    
    implCls.meta.push({name: ":keep", pos: cls.pos});
    // implCls.meta.push({name: Meta.RuntimeClass, pos: cls.pos});
    implCls.meta.push({name: ":valueType", pos: cls.pos});
    implCls.meta.push({name: ":unreflective", pos:cls.pos});
    implCls.meta.push({name: ":cppFileCode", params: [macro $v{'
#if __has_include("${cls.name}.g.cpp")
#include "${cls.name}.g.cpp"
#endif
'}], pos: cls.pos});

    Context.defineModule(pack.join(".") + "." + cls.name, [implCls, externClsT], imports, usings);
    
    // -- Define the `factory_implementation` type. --
    final filename = pack.concat([cls.name]).join("_");

    var pack = [];
    pack.push("winrt");
    pack = pack.concat(cls.pack);
    pack.push("factory_implementation");

    final externClsT2:TypeDefinition = macro class $classNameT<T, U> extends $base {}; // TODO: does it actually extend base?
    externClsT2.isExtern = true;
    externClsT2.pack = pack;
    externClsT2.meta.push({name: ":valueType", params: null, pos: cls.pos});
    externClsT2.meta.push({name: ":unreflective", params:[], pos:cls.pos});
    externClsT2.meta.push({name: ":include", params: [macro $v{externInclude}], pos: cls.pos});
    externClsT2.meta.push({name: ":filename", params: [macro $v{filename}], pos: cls.pos});
    externClsT2.meta.push({name: ":nativeTypeCode", params: [macro $v{'${classNameT}<{type0}, {type1}>'}], pos: cls.pos});
    Context.defineType(externClsT2);

    final classFacComplexType = TPath({name: cls.name, pack: pack});
    final classPathT2:TypePath = {name: externClsT2.name, pack: externClsT2.pack};
    final facCls:TypeDefinition = macro class $className extends $classPathT2<$classFacComplexType, $classImplComplexType> {
        // TODO: figure out what methods this class should have
        public function new() {}
    };

    facCls.meta.push({name: ":keep", params: null, pos: cls.pos});
    facCls.meta.push({name: ":valueType", params: null, pos: cls.pos});
    facCls.meta.push({name: ":unreflective", params:[], pos:cls.pos});
    facCls.meta.push({name: ":filename", params: [macro $v{filename}], pos: cls.pos});
    facCls.pack = pack;
    Context.defineType(facCls);

    #end
    return null;
}

@:autoBuild(winrt.tools.IRuntimeClass.build())
interface IRuntimeClass {}
