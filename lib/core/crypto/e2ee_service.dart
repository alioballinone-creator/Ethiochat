/// E2EE service interface for X3DH + Double Ratchet.
/// Design only in Phase 2; uses vetted patterns. Keys stored in secure storage.
/// messages.body can hold ciphertext.
abstract class E2eeService {
  Future<void> init();
  Future<Map<String, dynamic>> generateIdentityKeyPair();
  Future<List<Map<String, dynamic>>> generatePrekeys(int count);
  Future<String> encrypt(String conversationId, String plaintext);
  Future<String> decrypt(String conversationId, String ciphertext);
  Future<String> getSafetyNumber(String userId);
  Future<bool> verifySafetyNumber(String userId, String number);
}
