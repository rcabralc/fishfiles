# These optimizations were got from
# https://suzyahyah.github.io/cython/programming/2018/12/01/Gotchas-in-Cython.html

#cython: boundscheck=False
#cython: nonecheck=False
#cython: wraparound=False
#cython: infertypes=True
#cython: initializedcheck=False
#cython: cdivision=True

#cython: language_level=3

import operator
import re
import sre_constants
import sys
import unicodedata

from cython.view cimport array as carray


INT_SIZE = sizeof(int)

# Stuff used for fuzzy matching.
cdef int MIN_SCORE = -2**31 + 1 # make room for subtracting 1 without overflow
cdef int CONSECUTIVE_SCORE = 5
cdef int WORD_START_SCORE = 5


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

        pattern_lower = self.value.lower()

        if pattern_lower != pattern:
            self.value = pattern
            self.ignore_case = False
        else:
            self.value = pattern_lower
            self.ignore_case = True


class ExactPattern(SmartCasePattern):
    prefix = '@='

    def best_match(self, entry):
        if not self.length:
            return Match(0, ())

        value = entry.value
        if self.ignore_case:
            value = value.lower()

        if self.value not in value:
            return

        indices = []

        current = value.find(self.value)
        for index in range(current, current + self.length):
            indices.append(index)

        return Match(indices[len(indices) - 1] - indices[0], tuple(indices))


cdef class FuzzyPattern(object):
    cdef public str value
    cdef public int length
    cdef public bint ignore_case

    prefix = '@*'

    def __init__(self, str pattern):
        cdef str pattern_lower

        value = unicodedata.normalize('NFKD', pattern)

        if value:
            self.length = len(value)
        else:
            self.length = 0

        pattern_lower = value.lower()

        if pattern_lower != value:
            self.value = value
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

    # Fuzzy matching largely inspired by fzy.
    # https://github.com/jhawthorn/fzy
    # Using different weights for matching and a different strategy for
    # backtracking.
    cdef Match best_match(self, Entry entry):
        cdef int p_length = self.length

        if p_length == 0:
            return Match(0, ())

        cdef int v_length = entry.length
        cdef int r_limit = v_length - p_length + 1
        cdef int l_limit = 0
        cdef int pi, vi, prev_vi, score, best_score = MIN_SCORE, best_idx
        cdef int prev_score, last_match_score, match_score
        cdef str value, pattern, original_value
        cdef Py_UCS4 p
        cdef int[:,:,:] m

        original_value = entry.value
        value = entry.civalue if self.ignore_case else original_value
        pattern = self.value

        # m[X, Y, Z] stores the matching results
        # X = 0:1, 0 = best score, 1 = score if ending in the position
        # Y = 0:p_length-1, Z = 0:v_length-1 are the matrices of scores
        # in X=0, Z = v_length the first match index is stored for later
        # backtracking.
        # in X=1, Z = v_length, the best score index is stored, useful to jump
        # to the best score when backtracking.
        m = carray(shape=(2, p_length, v_length + 1),
                   itemsize=INT_SIZE,
                   format='i')

        for pi in range(p_length):
            p = pattern[pi]
            prev_score = best_score = MIN_SCORE
            for vi in range(l_limit, r_limit):
                if value[vi] == p:
                    prev_vi = vi - 1
                    # Record start index and bump l_limit.
                    if best_score == MIN_SCORE:
                        m[0, pi, v_length] = l_limit = vi
                    if (
                        # word delimiters
                        vi == 0 or value[prev_vi] in '._-/ ' or
                        # uppercase following lowercase, like 'w' in 'thisWord'
                        (original_value[vi].isupper() and
                         original_value[prev_vi].islower())
                    ):
                        score = WORD_START_SCORE
                    else:
                        score = 1
                    if pi != 0:
                        last_match_score = m[1, pi - 1, prev_vi]
                        score += m[0, pi - 1, prev_vi]
                        if last_match_score + CONSECUTIVE_SCORE > score:
                            score = last_match_score + CONSECUTIVE_SCORE
                else:
                    if best_score == MIN_SCORE: continue
                    score = MIN_SCORE

                m[1, pi, vi] = score
                if prev_score - 1 > score:
                    score = prev_score - 1
                m[0, pi, vi] = prev_score = score
                if score >= best_score: # >= because we want rightmost best.
                    m[1, pi, v_length] = vi
                    best_score = score
            # If we didn't improve best score, we failed to find a match for
            # `p`.
            if best_score == MIN_SCORE: return
            r_limit += 1
            l_limit += 1

        match_score = best_score
        indices = [0] * p_length
        best_idx = m[1, p_length - 1, v_length]
        indices[p_length - 1] = best_idx
        for pi in range(p_length - 2, -1, -1):
            p = pattern[pi]
            vi = best_idx - 1
            # Prefer to show a consecutive match if the score ending here is
            # the same as if it were not a match.  The final resulting score
            # would have been the same.
            if p == value[vi] and m[1, pi, vi] == m[0, pi, vi]:
                indices[pi] = best_idx = vi
                continue
            # Jump to the best score index if possible.
            if m[1, pi, v_length] < best_idx:
                indices[pi] = best_idx = m[1, pi, v_length]
                continue
            # Look for the best index, stop looking if score starts decreasing.
            # Might not find the best perfect match, as there are multiple
            # possible ways, but stopping early won't hurt.
            best_score = MIN_SCORE
            # Check only until start index, because after that numbers weren't
            # initialized.
            for vi in range(vi, m[0, pi, v_length] - 1, -1):
                score = m[0, pi, vi]
                if score <= best_score: break
                best_score = score
                best_idx = vi
            indices[pi] = best_idx

        return Match(-match_score, tuple(indices))


class InverseExactPattern(ExactPattern):
    prefix = '@!'

    def best_match(self, entry):
        if not self.length:
            return Match(0, ())

        value = entry.value
        if self.ignore_case:
            value = value.lower()

        if self.value in value:
            return

        return Match(0, ())


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

    def best_match(self, entry):
        if not self._can_match:
            return Match(0, ())

        value = entry.value
        match = self._re.search(value)
        if match is not None:
            indices = tuple(range(*match.span()))
            return Match(indices[len(indices) - 1] - indices[0], indices)

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

    cdef CompositeMatch match(self, Entry entry):
        cdef Match best_match
        cdef FuzzyPattern fuzzy_pattern
        cdef list matches = []

        for fuzzy_pattern in self._fuzzy_patterns:
            best_match = fuzzy_pattern.best_match(entry)

            if best_match is None:
                return

            matches.append(best_match)

        for pattern in self._patterns:
            best_match = pattern.best_match(entry)

            if best_match is None:
                return

            matches.append(best_match)

        return CompositeMatch(entry, tuple(matches))


cdef class Entry(object):
    cdef public int id
    cdef public str value
    cdef public str civalue
    cdef public int length
    cdef public dict data

    def __cinit__(self, int id, str value not None, dict data = {}):
        self.id = id
        value = unicodedata.normalize('NFKD', value)
        self.value = value
        self.civalue = value.lower()
        self.length = len(value)
        self.data = data

    cdef asdict(self):
        return dict(id=self.id, value=self.value, data=self.data)


cdef class Match:
    cdef public int rank
    cdef public tuple indices

    def __cinit__(self, int rank, tuple indices not None):
        self.rank = rank
        self.indices = indices


cdef class CompositeMatch(object):
    cdef public Entry entry
    cdef public tuple rank
    cdef tuple _matches

    def __cinit__(self, Entry entry not None, tuple matches not None):
        self.entry = entry
        self.rank = (*[m.rank for m in matches], len(entry.value), entry.id)
        self._matches = matches

    def asdict(self):
        return dict(rank=self.rank, partitions=self.partitions,
                    **self.entry.asdict())

    @property
    def partitions(self):
        return self._partitions(self._matches)

    def _partitions(self, tuple matches not None):
        cdef Match first_match
        cdef list indices
        cdef int length = len(matches)

        if length == 0:
            return [dict(unmatched=self.entry.value, matched='')]

        if length == 1:
            chunks = Chunks(matches[0].indices)
        else:
            first_match, *other_matches = self._matches
            indices = list(first_match.indices)
            for match in other_matches:
                indices.extend(match.indices)
            chunks = Chunks(tuple(sorted(set(indices))))
        return [dict(unmatched=unmatched, matched=matched)
                for unmatched, matched in chunks.items(self.entry.value)]


cdef class Chunks:
    cdef list _chunks

    def __cinit__(self, tuple indices not None):
        cdef int head
        cdef tuple tail
        cdef list chunks, chunk
        cdef int i

        if len(indices):
            head = indices[0]
            tail = indices[1:]
            chunk = [head, head + 1]
            chunks = [chunk]
            for i in range(len(tail)):
                t = tail[i]
                if t != chunk[1]:
                    chunk = [t, t + 1]
                    chunks.append(chunk)
                else:
                    chunk[1] = t + 1
            self._chunks = chunks
        else:
            self._chunks = None

    def items(self, str value not None):
        cdef int last_end = 0, i
        cdef list slice

        if self._chunks is not None:
            for i in range(len(self._chunks)):
                slice = self._chunks[i]
                yield value[last_end:slice[0]], value[slice[0]:slice[1]]
                last_end = slice[1]

        remainder = value[last_end:]
        if remainder:
            yield remainder, ''


class Contest(object):
    def __init__(self, *patterns):
        self.pattern = CompositePattern(list(patterns))

    def elect(self, entries not None, **kw):
        cdef Entry t
        cdef CompositeMatch m
        cdef CompositePattern p = self.pattern
        cdef list matches = []
        for t in entries:
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


def filter_entries(entries, *patterns, **options):
    patterns = [make_pattern(p) for p in patterns]
    return Contest(*patterns).elect(entries, **options)


def sort_matches(matches, **options):
    return Contest().rank(matches, **options)
