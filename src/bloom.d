/**
 * A bloom filter implementation
 *
 * Copyright: © 2013 - $(YEAR) Martin Nowak
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors: Martin Nowak
 *
 */
module bloom;
import core.bitop, std.typecons;

/**
 * A bloom filter is a fast and space-efficient probabilistic data
 * structure to test whether an element is member of a set.
 * False positive matches are possible, false negative matches are not.
 * Elements can only be added not removed.
 *
 * Asymptotic false-positive rates for different BitsPerEntry settings.
 * $(TABLE
 *   $(THEAD BitsPerEntry, False Positive Rate)
 *   $(TROW 1, 63.2%)
 *   $(TROW 2, 39.3%)
 *   $(TROW 3, 23.7%)
 *   $(TROW 4, 14.7%)
 *   $(TROW 5, 9.18%)
 *   $(TROW 6, 5.61%)
 *   $(TROW 7, 3.47%)
 *   $(TROW 8, 2.15%)
 *   $(TROW 9, 1.33%)
 * )
 * Params:
 *  BitsPerEntry = Set the number of bits allocated per entry.
 *  cheapHash = Use a faster but less good hash function.
 *
 * Macros:
 *   THEAD=$(TR $(THX $1, $+))
 *   THX=$(TH $1)$(THX $+)
 *   TROW=$(TR $(TDX $1, $+))
 *   TDX=$(TD $1)$(TDX $+)
 */
struct BloomFilter(size_t BitsPerEntry=4, CheapHash cheapHash=CheapHash.yes) if (BitsPerEntry > 0)
{
    /// no copying
    @disable this(this);

    /// construct a Bloom filter optimized for nentries
    this(size_t nentries)
    {
        resize(nentries);
    }

    /// insert a key
    void insert(size_t key)
    {
        immutable hashes = hash(key);
        foreach (i; SIota!K)
            bts(_p, hashes[i]);
    }

    /// test membership of key
    bool test(size_t key) const
    {
        immutable hashes = hash(key);
        foreach (i; SIota!K)
            if (!bt(_p, hashes[i])) return false;
        return true;
    }

    ~this()
    {
        reset();
    }

    /// free all bits
    void reset()
    {
        import core.stdc.stdlib : free;

        _size = 0;
        free(_p);
        _p = null;
    }

    /// clear all bits
    void clear()
    {
        import core.stdc.string : memset;

        memset(_p, 0, _size / 8);
    }

    /// get the reserved number of entries
    size_t size() const
    {
        return _size / M_N;
    }

    /// resize to nentries, all bits are cleared
    void resize(size_t nentries)
    in { assert(nentries); }
    body
    {
        import core.stdc.stdlib : realloc;

        nentries = cast(size_t)1 << 1 + bsr(nentries - 1); // next pow 2
        _size = M_N * nentries;
        assert(_size >= 8);
        _p = cast(size_t*)realloc(_p, _size / 8);
        if (_size) clear();
    }

private:
    // The optimal number of hash functions should be k = (m/n) * log(2)
    // The asymptotic false positive rate is (1 - e^(-k*n/m))^k.
    enum M_N = BitsPerEntry;
    enum K = cast(size_t)(M_N * LN2 + 0.5);
    enum real LN2 = 0x1.62e42fefa39ef35793c7673007e5fp-1L; /* ln 2  = 0.693147... */

    uint[K] hash(size_t key) const
    {
        uint[K] result = void;

        static if (cheapHash)
        {
            const(ubyte)* p = cast(ubyte*)&key;
            // rolling FNV-1a
            enum offset_basis = 2166136261;
            enum FNV_prime = 16777619;

            uint hash = offset_basis;
            foreach (i; SIota!(0, K))
            {
                hash ^= p[i % key.sizeof];
                hash *= FNV_prime;
                result[i] = hash;
            }
        }
        else
        {
            static if (K >= 1)
            {
                // Hsieh's Superfast Hash
                ulong h0 = key;
                h0 ^= h0 << 3;
                h0 += h0 >> 5;
                h0 ^= h0 << 4;
                h0 += h0 >> 17;
                h0 ^= h0 << 25;
                h0 += h0 >> 6;
                result[0] = cast(uint)(h0 - (h0 >> 32));
            }
            static if (K >= 2)
            {
                // Murmur Hash 3
                ulong h1 = key;
                h1 ^= h1 >> 16;
                h1 *= 0x85ebca6b;
                h1 ^= h1 >> 13;
                h1 *= 0xc2b2ae35;
                h1 ^= h1 >> 16;
                result[1] = cast(uint)(h1 - (h1 >> 32));
            }
            static if (K >= 3)
            {
                // fast-hash
                ulong h2 = key;
                h2 ^= h2 >> 23;
                h2 *= 0x2127599bf4325c37UL;
                h2 ^= h2 >> 47;
                result[2] = cast(uint)(h2 - (h2 >> 32));
            }
            static if (K > 3)
            {
                uint rol(uint n)(in uint x)
                {
                    return x << n | x >> 32 - n;
                }
                // Bob Jenkins lookup3 final mix
                uint h3 = result[0], h4 = result[1], h5 = result[2];
                h5 ^= h4; h5 -= rol!14(h4);
                h3 ^= h5; h3 -= rol!11(h5);
                h4 ^= h3; h4 -= rol!25(h3);
                h5 ^= h4; h5 -= rol!16(h4);
                h3 ^= h5; h3 -= rol!4(h5);
                h4 ^= h3; h4 -= rol!14(h3);
                h5 ^= h4; h5 -= rol!24(h4);
            }
            static if (K >= 4) result[3] = h3;
            static if (K >= 5) result[4] = h4;
            static if (K >= 6) result[5] = h5;
            static assert(K <= 6, "Only 6 hash functions defined but "~K.stringof~" needed for optimal results.");
        }

        immutable mask = _size - 1;
        foreach (i; SIota!(0, K))
            result[i] &= mask;

        return result;
    }

    size_t _size;
    size_t* _p;
}

/// Default BloomFilter for 16 entries.
unittest
{
    auto filter = BloomFilter!()(16);
    filter.insert(1);
    assert(filter.test(1));
    assert(!filter.test(2));
    filter.insert(2);
    assert(filter.test(2));
}

/// Using 6 bits per entry.
unittest
{
    auto filter = BloomFilter!6(16);
}

/// Using a better but slower hash function.
unittest
{
    auto filter = BloomFilter!(4, CheapHash.no)(16);
}

deprecated("Use CheapHash.yes or CheapHash.no instead.")
template BloomFilter(size_t BitsPerEntry=4, bool cheapHash=true) if (BitsPerEntry > 0)
{
    alias BloomFilter = BloomFilter!(BitsPerEntry, cast(CheapHash)cheapHash);
}

/// $(LINK2 http://dlang.org/phobos/std_typecons.html#.Flag,Flag) to specify whether or not a cheaper hash is used.
alias CheapHash = Flag!"cheapHash";

private:

template SIota(size_t start, size_t end) if (start <= end)
{
    template TT(T...) { alias TT = T; }
    static if (start < end)
        alias SIota = TT!(start, SIota!(start + 1, end));
    else
        alias SIota = TT!();
}

template SIota(size_t n)
{
    alias SIota = SIota!(0, n);
}

unittest
{
    template TT(T...) { alias TT = T; }
    enum N = 500;
    foreach (cheapHash; TT!(CheapHash.yes, CheapHash.no))
    {
        foreach (K; SIota!(1, 10))
        {
            auto filter = BloomFilter!(K, cheapHash)(N);
            assert(filter.size == 512);
            auto p = cast(size_t)&filter / 4096;
            filter.insert(p);
            assert(filter.test(p));

            foreach (i; 0 .. N)
            {
                filter.insert(p + i);
                assert(filter.test(p + i));
            }
            filter.clear();
            foreach (i; 0 .. N)
                assert(!filter.test(p + i));
        }
    }
}
