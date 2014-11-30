import std.datetime, std.stdio;
import dawg.bloom;

bool bench(size_t BitsPerEntry)(size_t nentries)
{
    writeln("bench BitsPerEntry ", BitsPerEntry, " nentries ", nentries);

    auto filter = BloomFilter!(4)(nentries);

    auto sw = StopWatch(AutoStart.yes);
    foreach (i; 0 .. nentries)
        filter.insert(i);
    writeln("insert took ", sw.peek.usecs, " µs"); sw.reset();
    foreach (i; 0 .. nentries)
        if (!filter.test(i)) return false;
    writeln("test took ", sw.peek.usecs, " µs"); sw.reset();
    return true;
}

int main()
{
    return !bench!(4)(1_000_000) || !bench!(8)(1_000_000);
}
