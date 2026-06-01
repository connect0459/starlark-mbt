nums = [3, 1, 4, 1, 5, 9, 2, 6]

print(sorted(nums))
print(sorted(nums, reverse=True))
print(min(nums), max(nums))

pairs = zip(["a", "b", "c"], [1, 2, 3])

print(list(pairs))

counts = {}
for n in nums:
    counts[n] = counts.get(n, 0) + 1

print(sorted(counts.items()))
print(any([False, False, True]))
print(all([True, True, False]))
print(list(enumerate(["x", "y", "z"])))
