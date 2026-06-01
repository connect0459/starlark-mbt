def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

def fib_list(n, start=0):
    return [fib(i) for i in range(start, n)]

print(fib(10))
print(fib_list(10))
print(fib_list(10, start=5))
