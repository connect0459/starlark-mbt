def clamp(x, lo, hi):
    if x < lo:
        return lo
    if x > hi:
        return hi
    return x

def pipeline(value, *fns):
    result = value
    for f in fns:
        result = f(result)
    return result
