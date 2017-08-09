""" Test classes and functions for the Annotator and Tracer.
"""

class Foo(object):
    
    def __init__(self, x=1, y=1):
        self.x = x
        self.y = y
    
    def apply(self, f):
        return (f(self.x), f(self.y))
    
    def do_sum(self):
        return self.x + self.y
    
    def do_prod(self):
        return self.x * self.y


class Bar(Foo):
    pass

class BarMixin(object):
    pass

class BarWithMixin(Bar, BarMixin):
    pass

class Baz(Bar, BarMixin):
    pass


class FooContainer(object):
    
    def __init__(self):
        self.foo = Foo()
    
    @property
    def foo_property(self):
        return self.foo


def create_foo():
    return Foo()

def nested_create_foo():
    foo = create_foo()
    return foo

def foo_x_sum(foos):
    return sum(foo.x for foo in foos)


def bar_from_foo(foo, x=None, y=None):
    return Bar(x if x else foo.x, y if y else foo.y)

def bar_from_foo_mutating(foo):
    foo.y = 0
    return Bar(foo.x, foo.y)
    
def baz_from_foo(foo):
    return Baz(foo.x, foo.y)

def baz_from_bar(bar):
    return Baz(bar.x, bar.y)


def sum_varargs(x, y=0, *args, **kw):
    return x + y + sum(args) + sum(kw.values())