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
            self.best_match = UnhighlightedMatch

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
        value = term.value
        if self.ignore_case:
            value = value.lower()

        if self.value not in value:
            return

        return ExactMatch(value, self)


class FuzzyPattern(SmartCasePattern):
    prefix = '@*'

    def best_match(self, term):
        cdef int i, j, length, best

        value = term.value
        length = term.length
        m = [[0] * (length + 1)]

        for i, p in enumerate(self.value):
            best = length + 1
            row = [None] * best
            best_index = current_length = None
            for j, c in enumerate(value):
                if m[i][j] is not None:
                    current_length = m[i][j]
                if current_length is not None:
                    current_length += 1
                if c == p and current_length is not None:
                    if current_length < best:
                        best = current_length
                        best_index = j
                    row[j + 1] = current_length
            if best_index is None:
                return
            m.append(row)

        indices = []
        for i in reversed(range(len(self.value))):
            indices.insert(0, best_index)
            while m[i][best_index] is None:
                best_index -= 1
            best_index = best_index - 1

        return FuzzyMatch(indices)


class InverseExactPattern(ExactPattern):
    prefix = '@!'

    def best_match(self, term):
        value = term.value
        if self.ignore_case:
            value = value.lower()

        if self.value in value:
            return

        return UnhighlightedMatch(term)


class RegexPattern(Pattern):
    prefix = '@/'

    def __init__(self, pattern, ignore_bad_patterns=True):
        super(RegexPattern, self).__init__(pattern)
        if pattern:
            self.value = '(?iu)' + pattern
            try:
                self._re = re.compile(self.value)
            except sre_constants.error:
                if not ignore_bad_patterns:
                    raise
                self.best_match = UnhighlightedMatch

    def best_match(self, term):
        value = term.value
        match = self._re.search(value)
        if match is not None:
            return RegexMatch(match)


class CompositePattern(object):
    def __init__(self, patterns):
        self._patterns = patterns

    def match(self, term):
        matches = []

        for pattern in self._patterns:
            best_match = pattern.best_match(term)

            if not best_match:
                return

            matches.append(best_match)

        return CompositeMatch(term, tuple(matches))


class UnhighlightedMatch(object):
    length = 0

    def __init__(self, term):
        pass

    @property
    def indices(self):
        return frozenset()


class ExactMatch(object):
    __slots__ = ('_value', '_pattern', 'length')

    def __init__(self, value, pattern):
        self._value = value
        self._pattern = pattern
        self.length = pattern.length

    @property
    def indices(self):
        indices = []

        string = self._value
        if self._pattern.ignore_case:
            string = string.lower()

        current = string.find(self._pattern.value)
        for index in range(current, current + self._pattern.length):
            indices.append(index)

        return frozenset(indices)


class FuzzyMatch(object):
    __slots__ = ('indices', 'length')

    def __init__(self, indices):
        self.length = indices[-1] - indices[0] + 1
        self.indices = frozenset(indices)


class RegexMatch(object):
    __slots__ = ('_match', 'length', 'indices')

    def __init__(self, match):
        self._match = match
        start, end = match.span()
        self.length = end - start
        self.indices = range(start, end)


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


class CompositeMatch(object):
    __slots__ = ('term', 'id', 'value', 'rank', '_matches')

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


class Term(object):
    __slots__ = ('id', 'value', 'length')

    def __init__(self, id, value):
        self.id = id
        self.value = value
        self.length = len(value)


class Contest(object):
    def __init__(self, *patterns):
        self.pattern = CompositePattern(list(patterns))

    def elect(self, terms, **kw):
        match = self.pattern.match
        limit = kw.get('limit', None)
        sort_limit = kw.get('sort_limit', None)
        key = operator.attrgetter('rank')
        # `is not None' is faster and None is common, so sub-case it for perf.
        matches = (m for m in (match(t) for t in terms) if m is not None and m)

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
