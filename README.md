bloom [![Build Status](https://travis-ci.org/MartinNowak/bloom.svg?branch=master)](https://travis-ci.org/MartinNowak/bloom) [![Coverage](https://codecov.io/gh/MartinNowak/bloom/branch/master/graph/badge.svg)](https://codecov.io/gh/MartinNowak/bloom) [![Dub](https://img.shields.io/dub/v/bloom.svg)](http://code.dlang.org/packages/bloom)
=====

A basic bloom filter.

# [Documentation](http://martinnowak.github.io/bloom/bloom.html)

# Example

```d
import bloom;

auto filter = BloomFilter!()(1024); // filter for 1024 entries
filter.insert(1);
assert(filter.test(1));
assert(!filter.test(2)); // might fail
filter.insert(2);
assert(filter.test(2));
```

