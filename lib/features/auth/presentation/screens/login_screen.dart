import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/datasources/auth_api.dart';
import '../../data/models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthApi _authApi;
  late final AuthSession _authSession;

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _authApi = context.read<AuthApi>();
    _authSession = context.read<AuthSession>();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authApi.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final user = await _authApi.getProfile();

      if (!mounted) return;

      _authSession.setCurrentUser(user);

      // AuthSession đã được cập nhật.
      // Màn hình gốc có thể theo dõi trạng thái đăng nhập
      // để chuyển sang giao diện chính.
    } on DioException catch (e) {
      debugPrint('========== DIO ERROR ==========');
      debugPrint('Type: ${e.type}');
      debugPrint('Message: ${e.message}');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Request URL: ${e.requestOptions.uri}');
      debugPrint('Request Method: ${e.requestOptions.method}');
      debugPrint('================================');
      if (!mounted) return;

      final responseData = e.response?.data;

      final message = responseData is Map
          ? responseData['message']?.toString()
          : null;

      _showMessage(
        message ?? 'Không thể kết nối hoặc đăng nhập thất bại.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : AppColors.success,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Ảnh thành phố phía trên, cắt cong ở cạnh dưới.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.31,
            child: ClipPath(
              clipper: _TopCityClipper(),
              child: Image.asset(
                'assets/images/login_city_top.png',
                width: screenWidth,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // Ảnh thành phố phía dưới.
          Positioned(
            left: 0,
            right: 0,
            bottom: 42,
            height: screenHeight * 0.19,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/login_city_bottom.png',
                fit: BoxFit.fill,
              ),
            ),
          ),

          // Footer nằm dưới ảnh thành phố.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Text(
              'EQUIPRENT · NỀN TẢNG CHO THUÊ THIẾT BỊ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: Color(0xFF405B87),
              ),
            ),
          ),

          // Nội dung đăng nhập.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBrand(screenWidth),

                          // Đẩy tiêu đề xuống dưới đường cong của ảnh.
                          SizedBox(height: screenHeight * 0.22),

                          const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF142B55),
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Đăng nhập để tiếp tục sử dụng ứng dụng.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Color(0xFF405578),
                            ),
                          ),

                          const SizedBox(height: 28),

                          _buildInput(
                            controller: _usernameController,
                            label: 'Tên đăng nhập',
                            hint: 'Nhập tên đăng nhập',
                            icon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập tên đăng nhập';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          _buildInput(
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            hint: 'Nhập mật khẩu',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isLoading) _login();
                            },
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 26),

                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1749A6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 22),
                                        SizedBox(width: 10),
                                        Text(
                                          'Đăng nhập',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Để nội dung không chạm vào ảnh phía dưới.
                          SizedBox(height: screenHeight * 0.20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand(double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/equiprent_logo.png',
          width: 58,
          height: 64,
          fit: BoxFit.contain,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EquipRent',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                'Nền tảng cho thuê thiết bị doanh nghiệp',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: screenWidth < 380 ? 10 : 11,
                  height: 1.3,
                  color: const Color.fromARGB(255, 42, 54, 73),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    required TextInputAction textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF142B55),
      ),

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,

        // Luôn hiển thị label phía trên ô nhập.
        floatingLabelBehavior: FloatingLabelBehavior.always,

        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF304A75),
        ),

        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF687FA5)),

        filled: true,
        fillColor: const Color(0xFFFFFFFF),

        prefixIcon: Icon(icon, size: 24, color: AppColors.primary),

        suffixIcon: suffixIcon,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFB8CCF3)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFB8CCF3), width: 1.3),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

class _TopCityClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 1.05,
        0,
        size.height * 0.82,
      )
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant _TopCityClipper oldClipper) => false;
}
