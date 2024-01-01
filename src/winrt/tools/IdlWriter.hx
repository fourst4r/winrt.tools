package winrt.tools;

import haxe.Resource;
import haxe.Template;
import haxe.io.Output;
import haxe.macro.Type;

using haxe.macro.TypeTools;

private final RuntimeClassTemplate = "

namespace ::namespace::
{
    [default_interface]
    runtimeclass ::name:: : ::base::
    {
        ::foreach fields::
        ::declaration::
        ::end::
    }
}
";

class IdlWriter {
    var o:Output;

    public function new(o:Output) {
        this.o = o;
        this.o.writeString("// This file was generated. Do not modify.\n\n");
    }

    public function writeType(type:Type) {
        switch (type) {
            case TInst(_.get() => t, params):
                writeClass(t);
            default:
                throw "Unsupported IDL type: "+type;
        }
    }

    public function writeClass(c:ClassType) {
        trace("writing idl for "+c.name+ "with superclass "+c.superClass.t.get().name );
        final tpl = new Template(RuntimeClassTemplate/*Resource.getString("RuntimeClass.mtt")*/);
        final namespace = c.pack.join(".");
        final ctx = {
            namespace: namespace,
            name: c.name,
            base: fullyQualifiedName(findBase(c)),
            fields: getTemplateFields(c),
        };
        o.writeString(tpl.execute(ctx));
    }

    function findBase(c:ClassType) {
        return switch (c.superClass) {
            case _.t.get() => sup:
                // if (sup.meta.has(Meta.BaseT)) {
                    // trace(sup.superClass);
                    // sup.superClass.t.get();
                    sup;
                // } else {
                    // findBase(sup);
                // }
            default:
                throw 'Couldn\'t find base class for $c';
        }
    }

    static function fullyQualifiedName(t:ClassType) {
        return t.pack.slice(1).map(namespaceCase).join(".") + "." + t.name;
    }

    static function namespaceCase(s:String) {
        if (s.length == 2) 
            // just a guess based on MS naming for UI and AI
            return s.toUpperCase();
        return s.substr(0, 1).toUpperCase() + s.substr(1);
    }

    function getTemplateFields(t:ClassType) {
        final fields = [];
        
        if (t.constructor?.get().isPublic) {
            fields.push({declaration: '${t.name}();'});
        }

        for (f in t.fields.get().filter(f -> f.isPublic && f.meta.has(Meta.Export))) {
            final str = idlField(f);
            if (str != null) {
                fields.push({declaration: str});
            }
        }
        
        return fields;
    }

    @:pure static function idlField(field:ClassField) {
        return switch (field.kind) {
            case FVar(AccNormal, AccNormal):
                '${idlType(field.type)} ${field.name};';
            case FMethod(MethNormal):
                switch (field.type) {
                    case TFun(args, ret):
                        '${idlType(ret)} ${field.name}();';
                    default:
                        null;
                }
            default:
                null;
        }
    }

    @:pure static function idlType(type:Type) {
        return switch (type) {
            case TAbstract(_.get() => t, []): 
                switch (t.name) {
                    case "Int": "Int32";
                    case "IInspectable": "Object";
                    case "Void": "void";
                    case name: name;
                }
            default: trace(type); "asds";
        }
    }
}