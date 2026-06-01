squares = [x * x for x in range(1, 6)]
evens = [x for x in range(20) if x % 2 == 0]
word_lengths = {w: len(w) for w in ["apple", "banana", "cherry"]}
flat = [x for row in [[1, 2], [3, 4], [5, 6]] for x in row]

print(squares)
print(evens)
print(word_lengths)
print(flat)
