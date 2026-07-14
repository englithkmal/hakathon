import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/register_device_body.dart';
import '../models/register_guest_device_body.dart';

abstract class DeviceRemoteDataSource {
  Future<void> registerGuest(RegisterGuestDeviceBody body);
  Future<void> registerDevice(RegisterDeviceBody body);
  Future<void> unregisterDevice(UnregisterDeviceBody body);
}

/// يتوقع جدول `devices` بالأعمدة:
/// id, user_id (nullable), token (unique), platform, device_name,
/// device_model, app_version, locale, created_at, updated_at
class DeviceRemoteDataSourceImpl implements DeviceRemoteDataSource {
  DeviceRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<void> registerGuest(RegisterGuestDeviceBody body) async {
    try {
      await _supabase.from('devices').upsert(
        {
          'token': body.token,
          'platform': body.platform,
          'device_name': body.deviceName,
          'device_model': body.deviceModel,
          'app_version': body.appVersion,
          'locale': body.locale,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<void> registerDevice(RegisterDeviceBody body) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
      }
      await _supabase.from('devices').upsert(
        {
          'user_id': userId,
          'token': body.token,
          'platform': body.platform,
          'device_name': body.deviceName,
          'device_model': body.deviceModel,
          'app_version': body.appVersion,
          'locale': body.locale,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<void> unregisterDevice(UnregisterDeviceBody body) async {
    try {
      await _supabase.from('devices').update({'user_id': null}).eq('token', body.token);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnknownException(message: e.toString());
    }
  }
}

final deviceRemoteDataSourceProvider = Provider<DeviceRemoteDataSource>((ref) {
  return DeviceRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
