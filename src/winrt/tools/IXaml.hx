package winrt.tools;

/**
    Interface for the functions generated by the XAML compiler.
**/
interface IXaml extends IRuntimeClass {
    private extern function InitializeComponent():Void;
}