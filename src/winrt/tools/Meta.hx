package winrt.tools;

enum abstract Meta(String) to String {
    var RuntimeClass = ":winrt.runtimeClass";
    var BaseT = ":winrt.baseT";
    var Export = ":winrt.export";
}