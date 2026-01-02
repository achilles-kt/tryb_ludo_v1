import 'package:flutter/material.dart';

class PhoneVerificationDisplay extends StatelessWidget {
  final String? linkedPhoneNumber; // null if not linked
  final bool codeSent;
  final bool isSaving;
  final TextEditingController phoneController;
  final TextEditingController otpController;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyOtp;
  final VoidCallback onChangeNumber; // E.g. to reset state

  const PhoneVerificationDisplay({
    super.key,
    required this.linkedPhoneNumber,
    required this.codeSent,
    required this.isSaving,
    required this.phoneController,
    required this.otpController,
    required this.onSendCode,
    required this.onVerifyOtp,
    required this.onChangeNumber,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF181B21);
    const primary = Color(0xFF3B82F6);
    const gold = Color(0xFFFACC15);
    const textMuted = Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_iphone, color: textMuted, size: 14),
              const SizedBox(width: 8),
              const Text("LINK PHONE NUMBER",
                  style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),

          // STATE A: LINKED
          if (linkedPhoneNumber != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(linkedPhoneNumber!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13))),
                  TextButton(
                      onPressed: onChangeNumber,
                      child: const Text("Change",
                          style: TextStyle(color: primary, fontSize: 12)))
                ],
              ),
            ),
          ] else ...[
            // STATE B: NOT LINKED / ENTERING
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10)),
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !codeSent,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "+1 234 567 8900",
                        hintStyle: TextStyle(color: Colors.white24),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!codeSent)
                  ElevatedButton(
                    onPressed: isSaving ? null : onSendCode,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text("Send Code",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
              ],
            ),

            if (codeSent) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold)),
                      child: TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Enter OTP",
                          hintStyle: TextStyle(color: Colors.white24),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isSaving ? null : onVerifyOtp,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text("Verify",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
