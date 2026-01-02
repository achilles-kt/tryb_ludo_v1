import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../profile/edit/phone_verification_display.dart';
import '../../theme/app_theme.dart';
import '../../utils/country_utils.dart';

class PhoneVerificationModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const PhoneVerificationModal({super.key, required this.onSuccess});

  @override
  State<PhoneVerificationModal> createState() => _PhoneVerificationModalState();
}

class _PhoneVerificationModalState extends State<PhoneVerificationModal> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isSaving = false;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _tryAutoFillCountryCode();
  }

  Future<void> _tryAutoFillCountryCode() async {
    if (_phoneController.text.isNotEmpty) return;
    final code = await CountryUtils.fetchCountryDialCode();
    if (code != null && mounted && _phoneController.text.isEmpty) {
      setState(() => _phoneController.text = "$code ");
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await AuthService.instance.verifyPhoneNumber(
          phoneNumber: phone,
          onCodeSent: (verificationId) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
                _isSaving = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Code sent! Check your SMS.")));
            }
          },
          onFail: (error) {
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Verification Failed: $error")));
            }
          },
          onAutoVerify: (credential) async {
            // Auto-verification
            await AuthService.instance.linkCredential(credential);
            await _finalizeVerification();
          });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) return;

    setState(() => _isSaving = true);
    try {
      await AuthService.instance.linkPhoneCredential(_verificationId!, otp);
      await _finalizeVerification();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Verification Error: $e")));
      }
    }
  }

  Future<void> _finalizeVerification() async {
    await UserProfileService.instance
        .linkPhoneNumber(number: _phoneController.text.trim());

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context); // Close this modal
      widget.onSuccess(); // Trigger success callback (open profile)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24),
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Verify Phone Number",
                  style: AppTheme.header.copyWith(fontSize: 20)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context))
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              "To sync contacts, we need to verify your phone number first. Matches are secure and hashed.",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 24),
          PhoneVerificationDisplay(
            linkedPhoneNumber: null, // We act as if not linked yet
            codeSent: _codeSent,
            isSaving: _isSaving,
            phoneController: _phoneController,
            otpController: _otpController,
            onSendCode: _sendCode,
            onVerifyOtp: _verifyOtp,
            onChangeNumber: () {
              setState(() {
                _codeSent = false;
                _verificationId = null;
              });
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
