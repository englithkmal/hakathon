import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/auth_session.dart' as app;
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<app.AuthSession> login(LoginBody body);
  Future<app.AuthSession> register(RegisterBody body);
  Future<UserModel> me();
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  });
  Future<void> logout();
}

/// يحوّل رقم الهاتف إلى "بريد" صناعي — Supabase Auth يتطلب email + password
/// لتسجيل الدخول بكلمة مرور. الرقم يبقى محفوظاً في profiles.phone.
String _syntheticEmail(String phoneE164) {
  final digits = phoneE164.replaceAll(RegExp(r'[^0-9]'), '');
  return '$digits@waffer.app';
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<app.AuthSession> login(LoginBody body) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: _syntheticEmail(body.phoneE164),
        password: body.password,
      );

      final supaUser = res.user;
      final session = res.session;
      if (supaUser == null || session == null) {
        throw const ServerException(message: 'فشل تسجيل الدخول.');
      }

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', supaUser.id)
          .maybeSingle();

      final user = UserModel.fromJson({
        'id': supaUser.id,
        'phone': body.phoneE164,
        ...profile ?? {},
      });

      return app.AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: user,
      );
    } on AuthException catch (e) {
      throw _mapAuth(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<app.AuthSession> register(RegisterBody body) async {
    try {
      final email = _syntheticEmail(body.phoneE164);
      final res = await _supabase.auth.signUp(
        email: email,
        password: body.password,
        data: {'phone': body.phoneE164},
      );

      var supaUser = res.user;
      var session = res.session;

      // بعض إعدادات Supabase تتطلب تأكيد البريد، وهنا لا نملك بريداً
      // حقيقياً — إذا لم تُرجع جلسة مباشرة، نحاول تسجيل الدخول فوراً.
      if (session == null) {
        final loginRes = await _supabase.auth.signInWithPassword(
          email: email,
          password: body.password,
        );
        supaUser = loginRes.user;
        session = loginRes.session;
      }

      if (supaUser == null || session == null) {
        throw const ServerException(
          message:
              'تم إنشاء الحساب لكن يتطلب تأكيد البريد. عطّل "Confirm email" من إعدادات Supabase Auth.',
        );
      }

      // حفظ بيانات الملف الشخصي
      await _supabase.from('profiles').upsert({
        'id': supaUser.id,
        'phone': body.phoneE164,
        'name': body.name,
        if (body.email != null) 'email': body.email,
        if (body.monthlyIncome != null) 'monthly_income': body.monthlyIncome,
        'currency': body.currency,
        'language': body.language,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final user = UserModel(
        id: supaUser.id,
        phoneE164: body.phoneE164,
        name: body.name,
        email: body.email,
        currency: body.currency,
        language: body.language,
        monthlyIncome: body.monthlyIncome,
      );

      return app.AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: user,
      );
    } on AuthException catch (e) {
      throw _mapAuth(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<UserModel> me() async {
    try {
      final supaUser = _supabase.auth.currentUser;
      if (supaUser == null) {
        throw const UnauthorizedException(
          message: 'غير مسجل الدخول.',
          statusCode: 401,
        );
      }
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', supaUser.id)
          .single();

      return UserModel.fromJson({
        'id': supaUser.id,
        'phone': profile['phone'] ?? '',
        ...profile,
      });
    } on AuthException catch (e) {
      throw _mapAuth(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  }) async {
    try {
      final supaUser = _supabase.auth.currentUser;
      if (supaUser == null) {
        throw const UnauthorizedException(
          message: 'غير مسجل الدخول.',
          statusCode: 401,
        );
      }
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (monthlyIncome != null) 'monthly_income': monthlyIncome,
        if (currency != null) 'currency': currency,
        if (language != null) 'language': language,
      };
      final result = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', supaUser.id)
          .select()
          .single();

      return UserModel.fromJson({
        'id': supaUser.id,
        'phone': result['phone'] ?? '',
        ...result,
      });
    } on AuthException catch (e) {
      throw _mapAuth(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw _mapAuth(e);
    }
  }

  AppException _mapAuth(AuthException e) {
    final msg = e.message;
    if (msg.contains('Invalid login credentials')) {
      return const UnauthorizedException(
        message: 'رقم الجوال أو كلمة المرور غير صحيحة.',
        statusCode: 401,
      );
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return const ValidationException(
        message: 'هذا الرقم مسجّل مسبقاً. سجّل الدخول مباشرة.',
        statusCode: 422,
      );
    }
    if (msg.contains('Password should be')) {
      return ValidationException(message: msg, statusCode: 422);
    }
    if (msg.contains('rate') || msg.contains('Too many')) {
      return RateLimitException(message: msg);
    }
    return ServerException(message: msg);
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
