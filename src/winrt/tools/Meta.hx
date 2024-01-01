package winrt.tools;

enum abstract Meta(String) to String {
    var RuntimeClass = ":winrt.runtimeClass";
    var BaseT = ":winrt.baseT";
    var Export = ":winrt.export";
    // Uses .xaml.
    var Xaml = ":winrt.xaml";
    // Don't generate a .idl file for this class.
    var NoIdl = ":winrt.noIdl";
}