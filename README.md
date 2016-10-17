bloom [![Build Status](https://travis-ci.org/MartinNowak/bloom.svg?branch=master)](https://travis-ci.org/MartinNowak/bloom) [![Coverage Status](https://coveralls.io/repos/MartinNowak/bloom/badge.svg?branch=master&service=github)](https://coveralls.io/github/MartinNowak/bloom?branch=master) [![Dub](https://img.shields.io/dub/v/bloom.svg)](http://code.dlang.org/packages/bloom)
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

