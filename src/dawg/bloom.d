/**
 * Contains a bloom filter implementation
 *
 * Copyright: Martin Nowak 2013 -.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 */

/*          Copyright Martin Nowak 2013 -.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module dawg.bloom;
import core.bitop;

// version=CHEAP_HASH;

/**
 * Basic bloom filter. This is a very fast data structure to test set
 * membership of a key.  It might give false positive results but
 * never false negative.
 *
 * Params:
 *  BitsPerEntry = Set the number of bits allocated per entry.
 *
 * Asymptotic false-positive rates for different BitsPerEntry:
 *
 * 1 - 63.2%
 * 2 - 39.3%
 * 3 - 23.7%
 * 4 - 14.7%
 * 5 - 9.18%
 * 6 - 5.61%
 * 7 - 3.47%
 * 8 - 2.15%
 * 9 - 1.33%
 */
struct BloomFilter(size_t BitsPerEntry=4) if (BitsPerEntry > 0)
{
    /// no copying
    @disable this(this);

    /// construct filter for nentries
    this(size_t nentries)
    {
        resize(nentries);
    }

    ~this()
    {
        reset();
    }

    /// frees all bits
    void reset()
    {
        import core.stdc.stdlib : free;

        _size = 0;
        free(_p);
        _p = null;
    }

    /// clears all bits
    void clear()
    {
        import core.stdc.string : memset;

        memset(_p, 0, _size / 8);
    }

    /// returns the number of entries
    size_t size() const
    {
        return _size / M_N;
    }

    /// resize for nentries members, clears all bits
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

    /// insert a key
    void insert(size_t key)
    {
        uint[K] hashes = void;
        hash(key, hashes);
        foreach (i; SIota!K)
            bts(_p, hashes[i]);
    }

    /// test membership of key
    bool test(size_t key) const
    {
        uint[K] hashes = void;
        hash(key, hashes);
        foreach (i; SIota!K)
            if (!bt(_p, hashes[i])) return false;
        return true;
    }

private:
    // The optimal number of hash functions should be k = (m/n) * log(2)
    // The asymptotic false positive rate is (1 - e^(-k*n/m))^k.
    enum M_N = BitsPerEntry;
    enum K = cast(size_t)(M_N * LN2 + 0.5);
    enum real LN2 = 0x1.62e42fefa39ef35793c7673007e5fp-1L; /** ln 2  = 0.693147... */

    void hash(size_t key, ref uint[K] result) const
    {
        version (CHEAP_HASH)
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
    }

    size_t _size;
    size_t* _p;
}

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
    enum N = 500;
    foreach (K; SIota!(1, 10))
    {
        auto filter = BloomFilter!(K)(N);
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
