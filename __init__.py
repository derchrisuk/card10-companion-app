import buttons
import color
import display
import leds
import urandom
import utime
import os


COLORS = [(0, 153, 51), (0, 153, 0), (51, 204, 51), (0, 102, 0), (102, 255, 102)]
LINE_AMOUNT = 50
DELAY_SEC = 0.03


class Drawer:
    "Drawer is a interface-like class with the draw method for the display."
    def draw(self, disp):
        pass


class Line:
    "A simple matrix-like Line, is used by the LineDrawer."
    def __init__(self):
        self._x = urandom.randint(0, 160)
        self._y = urandom.randint(0, 20)
        self._speed = urandom.randint(1, 15)
        self._elems = []

    def update_check(self):
        self._y += self._speed
        self._elems.append(urandom.choice(COLORS))

        return self._y < 80

    def __iter__(self):
        self._iter_id = 0
        return self

    def __next__(self):
        if self._iter_id >= len(self._elems):
            raise StopIteration
        elif self._y + self._iter_id >= 80:
            raise StopIteration
        else:
            col = self._elems[self._iter_id]
            self._iter_id += 1
            return ((self._x, self._y + self._iter_id), col)


class LineDrawer(Drawer):
    "LineDrawer draws multiple Lines for the matrix-like background."
    def __init__(self):
        self._lines = []
        for l in range(LINE_AMOUNT):
            self._lines.append(Line())

    def draw(self, disp):
        for i in range(LINE_AMOUNT):
            if not self._lines[i].update_check():
                self._lines[i] = Line()

            for p in self._lines[i]:
                disp.pixel(p[0][0], p[0][1],
                        col=color.Color(p[1][0], p[1][1], p[1][2]))


class TextDrawer(Drawer):
    "TextDrawer is an abstract class which draws the text from the _text method."
    def _text(self):
        pass

    def draw(self, disp):
        msg = self._text()
        disp.print(msg, fg=urandom.choice(COLORS),
                posx=80 - round(len(msg) / 2 * 14), posy=30)


class NickDrawer(TextDrawer):
    "NickDrawer draws the nickname from the nickname.txt file."
    def __init__(self):
        nick = "nickname.txt"
        if nick in os.listdir("."):
            f = open(nick, 'r')
            self._nick = f.read()
            f.close()
        else:
            self._nick = "No {}".format(nick)

    def _text(self):
        return self._nick


class TimeDrawer(TextDrawer):
    "TimeDrawer draws the current time, like a digital clock."
    def _text(self):
        t = utime.localtime()
        h, m, s = t[3], t[4], t[5]
        return "{:02}:{:02}:{:02}".format(h, m, s)


class NoneDrawer(Drawer):
    "NoneDrawer draws nothing to just show the background."
    def draw(self, disp):
        pass


def matrix_leds():
    for l in range(15):
        leds.set(l, urandom.choice(COLORS))


bg = LineDrawer()
fgs = [NoneDrawer(), NickDrawer(), TimeDrawer()]
fg_no = 0
leds_on = False

while True:
    pressed = buttons.read(buttons.BOTTOM_LEFT | buttons.BOTTOM_RIGHT | buttons.TOP_RIGHT)
    if pressed & buttons.BOTTOM_LEFT != 0:
        fg_no = fg_no-1 if fg_no > 0 else len(fgs)-1
    elif pressed & buttons.BOTTOM_RIGHT != 0:
        fg_no = fg_no+1 if fg_no < len(fgs)-1 else 0
    elif pressed & buttons.TOP_RIGHT != 0:
        leds_on = not leds_on
        if not leds_on:
            leds.clear()

    with display.open() as disp:
        disp.clear()
        bg.draw(disp)
        fgs[fg_no].draw(disp)
        disp.update()

    if leds_on:
        matrix_leds()

    utime.sleep(DELAY_SEC)
