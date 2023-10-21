package;

import haxe.io.Path;
import haxe.Template;
import sys.FileSystem;
import sys.io.File;

private typedef TemplateVars = {
    appname:String,
    namespace:String,
    author:String,
}

class Run {
    static final USAGE = "
Usage: haxelib run winrt.tools create <winrt|winui> <appname> <namespace> <author>
    create: makes a template project in a new folder";
    static final TEMPLATE_EXT = "mtt";

    static function main() {
        switch (Sys.args()) {
            case ["create", template, appname, namespace, author, path]:
                createTemplateProject(template, {appname: appname, namespace: namespace, author: author}, path);
            default:
                Sys.println(USAGE);
        }
    }

    static function createTemplateProject(template:String, vars:TemplateVars, path:String) {
        final src = './templates/$template';
        final dst = '$path/${vars.appname}';

        if (!FileSystem.exists(src)) {
            Sys.println('Error: No template exists with the name "$template"\n');
            Sys.println(USAGE);
            return;
        }

        templateCopy(src, dst, vars);
    }

    static function templateCopy(srcPath:String, dstPath:String, vars:TemplateVars) {
        FileSystem.createDirectory('$dstPath/src');
        for (filename in FileSystem.readDirectory(srcPath)) {
            final srcFile = '$srcPath/$filename';
            var dstFile = '$dstPath/$filename';
            if (Path.extension(filename) == TEMPLATE_EXT) {
                templateFileCopy(srcFile, Path.withoutExtension(dstFile), vars);
            } else {
                File.copy(srcFile, dstFile);
            }
        }
    }

    static function templateFileCopy(templateSrcFile:String, dstFile:String, vars:TemplateVars) {
        final fileText = File.read(templateSrcFile, false).readAll().toString();
        final template = new Template(fileText);
        final fi = File.write(dstFile);
        fi.writeString(template.execute(vars));
        fi.close();
    }
}