import functools
import operator
import re
import sre_constants
import sys


class Pattern(object):
    def __init__(self, pattern):
        self.value = pattern

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

        pattern_lower = pattern.lower()

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
            return UnhighlightedMatch

        value = term.value
        if self.ignore_case:
            value = value.lower()

        if self.value not in value:
            return

        return Match.from_exact(value, self)


class FuzzyPattern(SmartCasePattern):
    prefix = '@*'

    def best_match(self, term):
        cdef int i, j, length, best
        cdef str p, c, value
        cdef list m, row

        if not self.length:
            return UnhighlightedMatch

        value = term.value
        if self.ignore_case:
            value = value.lower()
        length = term.length
        m = [[0] * (length + 1)]

        for i, p in enumerate(self.value):
            best = length + 1
            row = [None] * best
            best_index = current_length = None
            for j, c in enumerate(value):
                if m[i][j] is not None:
                    current_length = m[i][j]
                if current_length is None: continue
                current_length += 1
                if c != p: continue
                row[j + 1] = current_length
                if current_length < best:
                    best = current_length
                    best_index = j
            if best_index is None:
                return
            m.append(row)

        indices = []
        for i in reversed(range(len(self.value))):
            indices.insert(0, best_index)
            while m[i][best_index] is None:
                best_index -= 1
            best_index = best_index - 1

        return Match(indices)


class InverseExactPattern(ExactPattern):
    prefix = '@!'

    def best_match(self, term):
        if not self.length:
            return UnhighlightedMatch

        value = term.value
        if self.ignore_case:
            value = value.lower()

        if self.value in value:
            return

        return UnhighlightedMatch


class RegexPattern(Pattern):
    prefix = '@/'

    def __init__(self, pattern, ignore_bad_patterns=True):
        super(RegexPattern, self).__init__(pattern)
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
            return UnhighlightedMatch

        value = term.value
        match = self._re.search(value)
        if match is not None:
            return Match.from_re(match)

        return


cdef class CompositePattern(object):
    cdef list _patterns

    def __init__(self, patterns):
        self._patterns = patterns

    cpdef CompositeMatch match(self, term):
        cdef Match best_match
        matches = []

        for pattern in self._patterns:
            best_match = pattern.best_match(term)

            if best_match is None:
                return

            matches.append(best_match)

        return CompositeMatch(term, tuple(matches))


class Term(object):
    __slots__ = ('id', 'value', 'length')

    def __init__(self, id, value):
        self.id = id
        self.value = value
        self.length = len(value)


cdef class Match:
    cdef public int length
    cdef public tuple indices

    def __init__(self, indices):
        if indices:
            self.length = indices[-1] - indices[0] + 1
        else:
            self.length = 0
        self.indices = tuple(indices)

    @classmethod
    def from_exact(cls, value, pattern):
        indices = []

        if pattern.ignore_case:
            value = value.lower()

        current = value.find(pattern.value)
        for index in range(current, current + pattern.length):
            indices.append(index)

        return cls(indices)

    @classmethod
    def from_re(cls, match):
        return cls(list(range(*match.span())))


UnhighlightedMatch = Match([])


cdef class CompositeMatch(object):
    cdef public object term
    cdef public object id
    cdef public str value
    cdef public tuple rank
    cdef tuple _matches

    def __init__(self, term, matches):
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


NoMatch = CompositeMatch(Term(0, ''), ())


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
            if i == chunk[-1] + 1:
                chunk.append(i)
            else:
                chunk = [i]
                chunks.append(chunk)

        for chunk in chunks:
            yield chunk[0], chunk[-1] + 1

    def merge(self, other):
        return type(self)(self.indices.union(other.indices))


class Contest(object):
    def __init__(self, *patterns):
        self.pattern = CompositePattern(list(patterns))

    def elect(self, terms, **kw):
        match = self.pattern.match
        limit = kw.get('limit', None)
        sort_limit = kw.get('sort_limit', None)
        key = operator.attrgetter('rank')
        matches = (m for m in (match(t) for t in terms) if m is not None)

        if sort_limit is None:
            processed_matches = sorted(matches, key=key)
        elif sort_limit <= 0:
            processed_matches = list(matches)
        else:
            processed_matches = list(matches)
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
    if isinstance(pattern, Pattern):
        return pattern
    for patternType in patternTypes:
        if pattern.startswith(patternType.prefix):
            return patternType(pattern[len(patternType.prefix):])
    return FuzzyPattern(pattern)


def filter_terms(terms, *patterns, **options):
    patterns = [make_pattern(p) for p in patterns]
    return Contest(*patterns).elect(terms, **options)
