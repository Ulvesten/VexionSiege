## Purpose: Wraps large float values with display helpers for exponential economy scaling.
extends RefCounted
class_name BigNum

var value: float = 0.0

static func from(v: float) -> BigNum:
	var b := BigNum.new()
	b.value = v
	return b

func add(other: BigNum) -> BigNum:
	return BigNum.from(value + other.value)

func sub(other: BigNum) -> BigNum:
	return BigNum.from(maxf(0.0, value - other.value))

func mul(factor: float) -> BigNum:
	return BigNum.from(value * factor)

func gte(other: BigNum) -> bool:
	return value >= other.value

func gt(other: BigNum) -> bool:
	return value > other.value

func eq(other: BigNum) -> bool:
	return value == other.value

func to_display() -> String:
	var v: float = value
	if v < 1_000.0:
		return str(int(v))
	elif v < 1_000_000.0:
		return "%.2fK" % (v / 1_000.0)
	elif v < 1_000_000_000.0:
		return "%.2fM" % (v / 1_000_000.0)
	elif v < 1_000_000_000_000.0:
		return "%.2fB" % (v / 1_000_000_000.0)
	elif v < 1_000_000_000_000_000.0:
		return "%.2fT" % (v / 1_000_000_000_000.0)
	return "%.2fP" % (v / 1_000_000_000_000_000.0)

func duplicate_num() -> BigNum:
	return BigNum.from(value)
