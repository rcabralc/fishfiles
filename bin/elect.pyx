# These optimizations were got from
# https://suzyahyah.github.io/cython/programming/2018/12/01/Gotchas-in-Cython.html

#cython: boundscheck=False
#cython: nonecheck=False
#cython: wraparound=False
#cython: infertypes=True
#cython: initializedcheck=False
#cython: cdivision=True

#cython: language_level=3

import functools
import operator
import re
import sre_constants
import sys
import unicodedata

from cython.view cimport array


class Pattern(object):
    def __init__(self, pattern):
        self.value = unicodedata.normalize('NFKD', pattern)

        if pattern:
            self.length = len(pattern)
        else:
            self.length = 0

    def __eq__(self, other):
        if isinstance(other, type(self)):
            return self.value == other.value
        return False

    def __hash__(self):
        return hash(self.value)

    def __len__(self):
        return self.length

    def __bool__(self):
        return self.length > 0

    __nonzero__ = __bool__


class SmartCasePattern(Pattern):
    def __init__(self, pattern):
        super(SmartCasePattern, self).__init__(pattern)

        pattern_lower = self.value.casefold()

        if pattern_lower != pattern:
            self.value = pattern
            self.ignore_case = False
        else:
            self.value = pattern_lower
            self.ignore_case = True


class ExactPattern(SmartCasePattern):
    prefix = '@='

    def best_match(self, term):
        if not self.length:
            return Match(term, [])

        value = term.value
        if self.ignore_case:
            value = value.casefold()

        if self.value not in value:
            return

        indices = []

        current = value.find(self.value)
        for index in range(current, current + self.length):
            indices.append(index)

        return Match(term, indices)


cdef class FuzzyPattern(object):
    cdef public str value
    cdef public int length
    cdef public bint ignore_case

    prefix = '@*'

    def __init__(self, str pattern):
        cdef str pattern_lower

        self.value = unicodedata.normalize('NFKD', pattern)

        if pattern:
            self.length = len(pattern)
        else:
            self.length = 0

        pattern_lower = pattern.casefold()

        if pattern_lower != pattern:
            self.value = pattern
            self.ignore_case = False
        else:
            self.value = pattern_lower
            self.ignore_case = True

    def __eq__(self, other):
        if isinstance(other, type(self)):
            return self.value == other.value
        return False

    def __hash__(self):
        return hash(self.value)

    def __len__(self):
        return self.length

    def __bool__(self):
        return self.length > 0

    __nonzero__ = __bool__

    cdef Match best_match(self, Term term):
        cdef int pi, vi
        cdef str value, pattern
        cdef list indices
        cdef int[:] lengths, match_lengths
        cdef int[:,:] m

        cdef int p_length = self.length

        if not p_length:
            return Match(term, [])

        cdef int v_length = term.length
        cdef int max_best_length = v_length + 1
        cdef int best_length = 0
        cdef int match_length
        cdef int r_limit = v_length - p_length + 1
        cdef int l_limit = 0

        value = term.value
        if self.ignore_case:
            value = value.casefold()
        pattern = self.value

        m = array(shape=(p_length, v_length),
                  itemsize=sizeof(int),
                  format='i')

        for pi in range(p_length):
            lengths = m[pi]
            p = pattern[pi]
            best_length = max_best_length
            for vi in range(l_limit, r_limit):
                if value[vi] == p:
                    # A match.
                    # If we didn't find a match for `p` so far, bump `l_limit`
                    # to `vi`, as there's no point checking past of it.  Note
                    # that it'll be increased by one in the end of the outer
                    # loop.
                    if best_length == max_best_length: l_limit = vi

                    # Add new match from increased length of previous match.
                    # If `pi` is zero `match_lengths` is not initialized, but
                    # we can fallback to 1.  Once we improve `best_length`
                    # below, `match_lengths` will be initialized, otherwise
                    # this method will just return.
                    match_length = match_lengths[vi - 1] + 1 if pi else 1
                    lengths[vi] = match_length
                    if match_length < best_length:
                        best_length = match_length
                elif best_length != max_best_length:
                    # Otherwise, if we already found a match for `p`
                    # (`best_length` for this `p` is not the maximum), just
                    # increase length from the previous iteration.  In this
                    # case, we know `vi - 1` is not out-of-bounds because we
                    # must have completed at least one iteration.
                    lengths[vi] = lengths[vi - 1] + 1
                # Otherwise, continue looping until the first match for `p` is
                # found.

            # If we didn't lower `best_length`, we failed to find a match for
            # `p`.
            if best_length == max_best_length: return
            match_lengths = lengths
            r_limit += 1
            l_limit += 1

        pi = p_length - 1
        p = pattern[pi]
        indices = []
        for vi in range(v_length - 1, -1, -1):
            # The last row of lengths might contain lengths greater than the
            # best, so we just skip them.  We skip also when we're not in a
            # match.
            if m[pi, vi] > best_length or p != value[vi]: continue
            # We're in a match.
            indices.insert(0, vi)
            # Break if we tested all pattern chars.
            if pi == 0: break
            pi -= 1
            p = pattern[pi]

        return Match(term, indices)


class InverseExactPattern(ExactPattern):
    prefix = '@!'

    def best_match(self, term):
        if not self.length:
            return Match(term, [])

        value = term.value
        if self.ignore_case:
            value = value.casefold()

        if self.value in value:
            return

        return Match(term, [])


class RegexPattern(Pattern):
    prefix = '@/'

    def __init__(self, pattern, ignore_bad_patterns=True):
        super(RegexPattern, self).__init__(pattern)
        self._can_match = False
        if pattern:
            self.value = '(?iu)' + pattern
            self._can_match = True
            try:
                self._re = re.compile(self.value)
            except sre_constants.error:
                if not ignore_bad_patterns:
                    raise
                self._can_match = False

    def best_match(self, term):
        if not self._can_match:
            return Match(term, [])

        value = term.value
        match = self._re.search(value)
        if match is not None:
            return Match(term, list(range(*match.span())))

        return


cdef class CompositePattern(object):
    cdef list _patterns
    cdef list _fuzzy_patterns

    def __init__(self, patterns):
        self._patterns = []
        self._fuzzy_patterns = []
        for p in patterns:
            if isinstance(p, FuzzyPattern):
                self._fuzzy_patterns.append(p)
            else:
                self._patterns.append(p)

    cdef CompositeMatch match(self, Term term):
        cdef Match best_match
        cdef FuzzyPattern fuzzy_pattern
        cdef list matches = []

        for fuzzy_pattern in self._fuzzy_patterns:
            best_match = fuzzy_pattern.best_match(term)

            if best_match is None:
                return

            matches.append(best_match)

        for pattern in self._patterns:
            best_match = pattern.best_match(term)

            if best_match is None:
                return

            matches.append(best_match)

        return CompositeMatch(term, tuple(matches))


cdef class Term(object):
    cdef public int id
    cdef public str value
    cdef public int length

    def __cinit__(self, int id, str value not None):
        self.id = id
        self.value = unicodedata.normalize('NFKD', value)
        self.length = len(value)


cdef class Match:
    cdef public int length
    cdef public tuple indices

    def __cinit__(self, Term term not None, list indices not None):
        if indices:
            self.length = indices[len(indices) - 1] - indices[0] + 1
        else:
            self.length = term.length
        self.indices = tuple(indices)


cdef class CompositeMatch(object):
    cdef public Term term
    cdef public int id
    cdef public str value
    cdef public tuple rank
    cdef tuple _matches

    def __cinit__(self, Term term not None, tuple matches not None):
        self.term = term
        self.id = term.id
        self.value = term.value
        self.rank = (sum(m.length for m in matches), len(term.value), term.id)
        self._matches = matches

    def asdict(self):
        return dict(id=self.id, value=self.value,
                    rank=self.rank, partitions=self.partitions)

    @property
    def partitions(self):
        partitions = []
        last_end = 0
        value = self.value

        for start, end in sorted(self._spans()):
            partitions.append(dict(
                unmatched=value[last_end:start],
                matched=value[start:end]
            ))
            last_end = end

        remainder = value[last_end:]

        if remainder:
            partitions.append(dict(unmatched=remainder, matched=''))

        return partitions

    def _spans(self):
        if not self._matches:
            return

        streaks = functools.reduce(
            lambda acc, streaks: acc.merge(streaks),
            (Streaks(m.indices) for m in self._matches)
        )
        for start, end in streaks:
            yield (start, end)


class Streaks(object):
    def __init__(self, indices):
        self.indices = frozenset(indices)

    def __iter__(self):
        if not self.indices:
            return

        indices = sorted(self.indices)

        (head,), tail = indices[0:1], indices[1:]
        chunks = [[head]]
        (chunk,) = chunks
        for i in tail:
            if i == chunk[len(chunk) - 1] + 1:
                chunk.append(i)
            else:
                chunk = [i]
                chunks.append(chunk)

        for chunk in chunks:
            yield chunk[0], chunk[len(chunk) - 1] + 1

    def merge(self, other):
        return type(self)(self.indices.union(other.indices))


class Contest(object):
    def __init__(self, *patterns):
        self.pattern = CompositePattern(list(patterns))

    def elect(self, terms not None, **kw):
        cdef Term t
        cdef CompositeMatch m
        cdef CompositePattern p = self.pattern
        cdef list matches = []
        for t in terms:
            m = p.match(t)
            if m is not None:
                matches.append(m)
        return self.rank(matches, **kw)

    def rank(self, list matches not None, **kw):
        limit = kw.get('limit', None)
        sort_limit = kw.get('sort_limit', None)
        key = operator.attrgetter('rank')

        if sort_limit is None:
            processed_matches = sorted(matches, key=key)
        elif sort_limit <= 0:
            processed_matches = matches
        else:
            processed_matches = matches
            if len(processed_matches) < sort_limit:
                processed_matches = sorted(processed_matches, key=key)

        if limit is not None:
            processed_matches = processed_matches[:limit]

        if kw.get('reverse', False):
            processed_matches = list(reversed(processed_matches))

        return processed_matches


patternTypes = [
    FuzzyPattern,
    RegexPattern,
    ExactPattern,
    InverseExactPattern,
]

def make_pattern(pattern):
    if isinstance(pattern, Pattern) or isinstance(pattern, FuzzyPattern):
        return pattern
    for patternType in patternTypes:
        if pattern.startswith(patternType.prefix):
            return patternType(pattern[len(patternType.prefix):])
    return FuzzyPattern(pattern)


def filter_terms(terms, *patterns, **options):
    patterns = [make_pattern(p) for p in patterns]
    return Contest(*patterns).elect(terms, **options)


def sort_matches(matches, **options):
    return Contest().rank(matches, **options)
