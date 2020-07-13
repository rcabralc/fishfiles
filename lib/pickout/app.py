from PyQt5.QtCore import QObject, pyqtSlot, pyqtSignal, Qt
from PyQt5.QtGui import QPalette
from PyQt5.QtWebKitWidgets import QWebView
from PyQt5.QtWidgets import QApplication
from itertools import takewhile, zip_longest

import elect
import json
import os
import sys


MAX_HISTORY_ENTRIES = 100

Term = elect.Term


def filter(terms, pat, **options):
    if ' ' not in pat and '\\' not in pat:
        # Optimization for the common case of a single pattern:  Don't parse
        # it, since it doesn't contain any special character.
        patterns = [pat]
    else:
        it = iter(pat.lstrip())
        c = next(it, None)

        patterns = [[]]
        pattern, = patterns

        # Pattern splitting.
        #
        # Multiple patterns can be entered by separating them with ` `
        # (spaces).  A hard space is entered with `\ `.  The `\` has special
        # meaning, since it is used to escape hard spaces.  So `\\` means `\`
        # while `\ ` means ` `.
        #
        # We need to consume each char and test them, instead of trying to be
        # smart and do search and replace.  The following must hold:
        #
        # 1. `\\ ` translates to `\ `, but the whitespace is not escaped
        #    because its preceding `\` is the result of a previous escape (so
        #    this breaks the pattern).
        #
        # 2. `\\\ ` translates to `\ `, but there are two escapes: one for the
        #    `\` and other for the ` ` (so this is a hard space and will not
        #    lead to a break in the pattern).
        #
        # And so on; escapes must be interpreted in the order they occur, from
        # left to right.
        #
        # I couldn't figure out a way of doing this with search and replace
        # without temporarily replacing one string with a possibly unique
        # sequence and later replacing it again (but this is weak).
        while c is not None:
            if c == '\\':
                pattern.append(next(it, '\\'))
            elif c == ' ':
                pattern = []
                patterns.append(pattern)
            else:
                pattern.append(c)
            c = next(it, None)

        patterns = [''.join(p) for p in patterns if p]

    return incremental_filter(terms, patterns, **options)


class Pattern:
    def __init__(self, inner):
        self.inner = inner

    def __eq__(self, other):
        return isinstance(other, type(self)) and other.inner == self.inner

    def __hash__(self):
        return hash(self.inner)


class IncrementalPattern(Pattern):
    def exhaust(self):
        for i in range(len(self.inner.value) - 1, -1, -1):
            yield type(self)(type(self.inner)(self.inner.value[0:i + 1]))

    def __repr__(self):
        return 'IncrementalPattern({}, inner={})'.format(
            repr(self.inner.value),
            repr(self.inner)
        )


class NonIncrementalPattern(Pattern):
    pass


def wrap_pattern(elect_pattern):
    if (type(elect_pattern) == elect.FuzzyPattern or
            type(elect_pattern) == elect.ExactPattern):
        return IncrementalPattern(elect_pattern)
    return NonIncrementalPattern(elect_pattern)


def incremental_filter(terms, pattern_strings, debug=False, **options):
    patterns = [wrap_pattern(elect.make_pattern(p))
                for p in pattern_strings]

    def full_filter(items):
        return elect.filter_terms(items, *[p.inner for p in patterns],
                                  **options)

    non_incremental_patterns = [p for p in patterns
                                if not isinstance(p, IncrementalPattern)]
    if non_incremental_patterns or not patterns:
        return full_filter(terms)

    def candidates_from_cache(patterns):
        def best_possible_patterns(patterns):
            groups = {}

            for pattern in patterns:
                groups.setdefault(type(pattern), []).append(pattern)

            for t, patterns in groups.items():
                yield (t, frozenset(patterns))

        find = incremental_cache.find
        best_patterns, cached = find(patterns, debug=debug)

        if best_patterns == set(best_possible_patterns(patterns)):
            return elect.sort_matches(list(cached), **options)

        for t, best in best_patterns:
            if best:
                # There was at least one partial hit for one pattern, so
                # cached, even if empty, is the result of some previous
                # filtering.
                return full_filter(r.term for r in cached)

        # No hit for these patterns.
        return full_filter(terms)

    def update_candidates_from_cache(patterns, matches):
        incremental_cache.update(patterns, matches, debug=debug)
        return matches

    matches = candidates_from_cache(patterns)
    return update_candidates_from_cache(patterns, matches)


class Mode:
    def __init__(self, name, prompt):
        self.name = name
        self.prompt = prompt


insert_mode = Mode('insert', '>')
history_mode = Mode('history', '<')


class EmptyHistory:
    def prev(self, input): return False, input
    def next(self, input): return False, input
    def add(self, _): return
    def go_to_end(self): return


class History:
    @classmethod
    def build(cls, history_path, key):
        if not key or not history_path:
            return EmptyHistory()

        if not os.path.exists(history_path):
            os.makedirs(os.path.dirname(history_path), exist_ok=True)
            with open(history_path, 'w') as f:
                f.write(json.dumps({}))

        return cls(history_path, key)

    def __init__(self, history_path, key):
        self._history_path = history_path
        self._key = key
        self._all_entries = self._load()
        self._entries = self._all_entries.get(self._key, [])
        self._index = len(self._entries)

    def next(self, input):
        cut_index = min(len(self._entries), self._index + 1)
        entries = self._entries[cut_index:]
        for index, entry in enumerate(entries):
            if entry.startswith(input):
                self._index = cut_index + index
                return True, entry
        self.go_to_end()
        return False, input

    def prev(self, input):
        cut_index = max(0, self._index)
        entries = self._entries[:cut_index]
        for index, entry in reversed(list(enumerate(entries))):
            if entry.startswith(input):
                self._index = index
                return True, entry
        return False, self._entries[self._index]

    def add(self, entry):
        if not entry:
            return

        if entry in self._entries:
            self._entries.remove(entry)
        self._entries.append(entry)

        diff = len(self._entries) - MAX_HISTORY_ENTRIES

        if diff > 0:
            self._entries = self._entries[diff:]

        self._all_entries[self._key] = self._entries
        self.go_to_end()
        self._dump()

    def go_to_end(self):
        self._index = len(self._entries)

    def _load(self):
        with open(self._history_path, 'r') as history_file:
            return json.loads(history_file.read())

    def _dump(self):
        with open(self._history_path, 'w') as history_file:
            history_file.write(json.dumps(self._all_entries, indent=2,
                                          sort_keys=True))


class Frontend:
    _view = _frame = None

    def __init__(self, view, frame):
        self._view = view
        self._frame = frame

    def plug(self, app, items, **kw):
        title = kw.pop('title', None)
        input = kw.pop('input', '')
        self._menu = Menu(self, items, **kw)
        self._menu.setParent(self._view)
        self._frame.addToJavaScriptWindowObject('backend', self._menu)
        self.set_input(input)
        self._view.restore(title=title)
        self._menu.input = input
        return self._menu

    def unplug(self):
        self._evaluate('window.backend = null')
        self._menu = None
        self._view.hide()

    def set_input(self, input):
        self._evaluate("frontend.setInput(%s)" % json.dumps(input))

    def show_items(self, items):
        self._evaluate("frontend.setItems(%s)" % json.dumps(items))

    def select(self, index):
        self._evaluate('frontend.select(%d)' % index)

    def over_limit(self):
        self._evaluate("frontend.overLimit()")

    def under_limit(self):
        self._evaluate("frontend.underLimit()")

    def update_counters(self, selected, total):
        self._evaluate("frontend.updateCounters(%d, %d)" % (selected, total))

    def report_mode(self, mode):
        self._evaluate("frontend.switchPrompt(%s)" % json.dumps(mode.prompt))
        self._evaluate("frontend.reportMode(%s)" % json.dumps(mode.name))

    def _evaluate(self, js):
        self._frame.evaluateJavaScript(js)


class ModeState:
    def __init__(self, mode, input, frontend=None):
        self._mode = mode
        self.input = input
        self.frontend = frontend

    def switch(self, mode, input):
        if self._mode is mode:
            return self
        return type(self)(mode, input, self.frontend).report()

    def report(self):
        self.frontend.report_mode(self._mode)
        return self


class Selection:
    def initialize(self, index, value):
        self.index = index
        self.value = value


class Menu(QObject):
    selected = pyqtSignal(str)

    _selected_count = _total_items = _index = 0
    _input = None
    _results = []
    _history_path = os.path.join(os.path.dirname(__file__), 'history.json')

    def __init__(self,
                 frontend,
                 items,
                 limit=None,
                 sep=None,
                 history_key=None,
                 delimiters=[],
                 accept_input=False,
                 keep_empty_items=False,
                 debug=False):
        super(Menu, self).__init__()

        def keep(item):
            return keep_empty_items or item.strip()

        incremental_cache.clear()
        self._frontend = frontend

        self._all_terms = [Term(i, c) for i, c in enumerate(items) if keep(c)]
        self._history = History.build(self._history_path, history_key)
        self._total_items = len(items)
        self._limit = limit
        self._completion_sep = sep
        self._word_delimiters = delimiters
        self._accept_input = accept_input
        self._debug = debug
        self._mode_state = ModeState(insert_mode, input, frontend)

    @property
    def input(self):
        return self._input or ''

    @input.setter
    def input(self, value):
        value = value or ''
        if self._input != value:
            self._input = value
            self.results = filter(self._all_terms, value,
                                  incremental=True, debug=self._debug)

    @property
    def results(self):
        return self._results

    @results.setter
    def results(self, results):
        limit = self._limit
        materialized_results = list(results)
        self._selected_count = len(materialized_results)

        if limit is not None:
            current_items = materialized_results[:limit]

            if self._selected_count > limit:
                self._over_limit()
            else:
                self._under_limit()
        else:
            current_items = materialized_results
            self._under_limit()

        self._index = max(0, min(self._index, len(current_items) - 1))
        self._results = current_items
        self._render_items()
        self._render_counters()

    @pyqtSlot(str)
    def log(self, message):
        sys.stderr.write(message + "\n")
        sys.stderr.flush()

    @pyqtSlot(str)
    def filter(self, input):
        self.input = input

    @pyqtSlot(str)
    def enter(self, input):
        self.input = input
        self._mode_state = self._mode_state.switch(insert_mode, input)
        self._history.go_to_end()
        return input

    @pyqtSlot()
    def acceptSelected(self):
        selected = self.getSelected()
        if selected:
            self._history.add(self.input)
            self.selected.emit(selected)

    @pyqtSlot()
    def acceptInput(self):
        if self._accept_input:
            self._history.add(self.input)
            self.selected.emit(self.input)

    @pyqtSlot(result=str)
    def getSelected(self):
        items = self.results
        if items:
            return items[min(self._index, len(items) - 1)].value.strip()
        return ''

    @pyqtSlot()
    def next(self):
        self._index = min(self._index + 1, len(self.results) - 1)
        self._frontend.select(self._index)

    @pyqtSlot()
    def prev(self):
        self._index = max(self._index - 1, 0)
        self._frontend.select(self._index)

    @pyqtSlot(result=str)
    def historyNext(self):
        self._mode_state = self._mode_state.switch(history_mode, self.input)
        _, entry = self._history.next(self._mode_state.input)
        return entry

    @pyqtSlot(result=str)
    def historyPrev(self):
        self._mode_state = self._mode_state.switch(history_mode, self.input)
        _, entry = self._history.prev(self._mode_state.input)
        return entry

    @pyqtSlot(result=str)
    def complete(self):
        def allsame(chars_at_same_position):
            return len(set(chars_at_same_position)) == 1

        return ''.join(c for c, *_ in takewhile(
            allsame,
            zip_longest(*self._candidates_for_completion())
        )) or self.input

    @pyqtSlot()
    def dismiss(self):
        self.selected.emit('')

    @pyqtSlot(result=str)
    def wordDelimiters(self):
        delimiters = [' ']
        if self._word_delimiters:
            delimiters.extend(self._word_delimiters)
        return ''.join(delimiters)

    def _render_items(self):
        items = [item.asdict() for item in self.results]
        if items:
            items[self._index]['selected'] = True
        self._frontend.show_items(items)

    def _render_counters(self):
        self._frontend.update_counters(self._selected_count, self._total_items)

    def _candidates_for_completion(self):
        default = list(self._values_for_completion())
        values = None

        if self._completion_sep:
            values = self._values_until_next_sep(default, len(self.input))

        return values or default

    def _values_for_completion(self):
        sw = str.startswith
        input = self.input
        return (t.value for t in self._all_terms if sw(t.value, input))

    def _values_until_next_sep(self, values, from_index):
        sep = self._completion_sep
        find = str.find
        return {
            string[:result + 1]
            for result, string in (
                (find(string, sep, from_index), string)
                for string in values
            ) if ~result
        }

    def _over_limit(self):
        self._frontend.over_limit()

    def _under_limit(self):
        self._frontend.under_limit()


class MainView(QWebView):
    def __init__(self, parent=None):
        super(MainView, self).__init__(parent)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)

    def restore(self, title=None):
        frameGeometry = self.frameGeometry()
        desktop = QApplication.desktop()
        screen = desktop.screenNumber(desktop.cursor().pos())
        centerPoint = desktop.screenGeometry(screen).center()
        frameGeometry.moveCenter(centerPoint)
        self.move(frameGeometry.topLeft())

        if title is not None:
            self.setWindowTitle(title)

        self.activateWindow()

        return self.showNormal()


def default_colors(palette):
    def color(role_name):
        role = getattr(QPalette, role_name)
        c = palette.color(role)
        return "%d,%d,%d" % (c.red(), c.green(), c.blue())

    def disabled(role_name):
        role = getattr(QPalette, role_name)
        c = palette.color(QPalette.Disabled, role)
        return "%d,%d,%d" % (c.red(), c.green(), c.blue())

    def inactive(role_name):
        role = getattr(QPalette, role_name)
        c = palette.color(QPalette.Inactive, role)
        return "%d,%d,%d" % (c.red(), c.green(), c.blue())

    return {
        "background-color": color('Window'),
        "color": color('WindowText'),
        "prompt-color": color('Link'),
        "prompt-over-limit-color": color('LinkVisited'),
        "input-not-found-color": disabled('WindowText'),
        "input-history-color": color('Link'),
        "entries-background-color": color('Base'),
        "entries-alternate-background-color": color('AlternateBase'),
        "entries-color": color('Text'),
        "entries-hl-background-color": color('Highlight'),
        "entries-hl-color": color('HighlightedText'),
    }


def apply_default_colors(palette, theme):
    colors = default_colors(palette)
    colors.update(theme)
    return colors


def interpolate_html(template, palette, config):
    theme = apply_default_colors(palette, config.get('theme', {}))

    for key, value in theme.items():
        template = template.replace(f'%({key})s', value)
    return template.replace('%(initial-value)s', '')


class MenuApp(QObject):
    finished = pyqtSignal()

    def __init__(self, title=None):
        super(MenuApp, self).__init__()
        self.app = QApplication(sys.argv)

        basedir = os.path.dirname(__file__)

        with open(os.path.join(basedir, 'menu.html')) as f:
            self._html = f.read()

        with open(os.path.join(basedir, 'jquery.js')) as f:
            self._jquery_source = f.read()

        with open(os.path.join(basedir, 'menu.js')) as f:
            self._frontend_source = f.read()

        config_path = os.path.join(basedir, 'menu.json')
        if not os.path.exists(config_path):
            os.makedirs(os.path.dirname(config_path), exist_ok=True)
            with open(config_path, 'w') as f:
                f.write(json.dumps({}))

        with open(config_path) as f:
            self._config = json.loads(f.read())

        view = MainView()
        view.setHtml(interpolate_html(self._html, view.palette(),
                                      self._config))
        frame = view.page().mainFrame()
        frame.evaluateJavaScript(self._jquery_source)
        frame.evaluateJavaScript(self._frontend_source)

        self._frontend = Frontend(view, frame)

    def setup(self, items, **kw):
        return self._frontend.plug(self.app, items, **kw)

    def hide(self):
        self._frontend.unplug()

    def exec_(self):
        self.app.exec_()
        return self.finished.emit()

    def quit(self):
        self.finished.emit()
        return self.app.quit()


class PatternCache(object):
    def __init__(self):
        self._cache = {}

    def update(self, patterns, matches, debug=False):
        if debug:
            def debug(fn): sys.stderr.write(fn())
        else:
            def debug(fn): return

        patterns = tuple(patterns)
        debug(lambda: "updating cache for patterns: {}\n".format(patterns))
        self._cache[patterns] = frozenset(matches)

    def find(self, patterns, default=frozenset(), debug=False):
        patterns = tuple(patterns)
        cached = None
        best_pattern = ()

        if debug:
            def debug(fn): sys.stderr.write(fn())
        else:
            def debug(fn): return

        for expansion in self._exhaust(patterns):
            debug(lambda: "attempting expansion: {}\n".format(expansion))
            from_cache = self._cache.get(expansion, None)

            if not from_cache:
                continue

            if cached is None or len(from_cache) < len(cached):
                debug(lambda: "cache: hit on {}\n".format(expansion))
                debug(lambda: "cache size: {}\n".format(len(from_cache)))
                best_pattern = expansion
                cached = from_cache
                break

        if cached is None:
            debug(lambda: "cache: miss, patterns: {}\n".format(patterns))
            return (frozenset(), default)

        if best_pattern == patterns:
            debug(lambda: "using result directly from cache\n")

        return (frozenset(best_pattern), cached)

    def _exhaust(self, patterns):
        if len(patterns) == 1:
            for exhaustion in patterns[0].exhaust():
                yield (exhaustion,)
            return

        for i in range(len(patterns) - 1, -1, -1):
            pattern = patterns[i]
            lpatterns = patterns[:i]
            rpatterns = patterns[i + 1:]

            for exhaustion in pattern.exhaust():
                for subexhaustion in self._exhaust(rpatterns):
                    yield lpatterns + (exhaustion,) + subexhaustion


class IncrementalCache(object):
    def __init__(self):
        self._cache = {}

    def clear(self):
        self._cache.clear()

    def update(self, patterns, matches, debug=False):
        if len(set(type(p) for p in patterns)) == 1:
            self._cache[type(patterns[0])].update(patterns, matches,
                                                  debug=debug)

    def find(self, patterns, default=frozenset(), debug=False):
        for pattern in patterns:
            self._cache.setdefault(type(pattern), PatternCache())

        best_patterns = set()
        matches = set()
        for t, best, cached in self._get_terms(patterns, default, debug):
            best_patterns.add((t, best))
            matches.update(cached)

        return (best_patterns, matches)

    def _get_terms(self, patterns, default, debug):
        for pattern_type, patterns in self._group_types(patterns):
            best_pattern, cached = self._cache[pattern_type].find(
                patterns, default=default, debug=debug
            )
            yield (pattern_type, best_pattern, cached)

    def _group_types(self, patterns):
        groups = {}

        for pattern in patterns:
            group = groups.setdefault(type(pattern), [])
            group.append(pattern)

        for t, patterns in groups.items():
            yield (t, patterns)


incremental_cache = IncrementalCache()


def run(items, **kw):
    app = MenuApp()
    selected = app.setup(items, **kw).selected
    selected.connect(lambda r: print(r) if r else None)
    selected.connect(lambda _: app.quit())
    return app.exec_()
