package dev.flutter.plugins.integration_test;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Release-only no-op for Flutter's generated plugin registrant.
 *
 * integration_test is a dev dependency, so its real Android plugin is not on
 * the release classpath. Flutter 3.38 still lists that dev plugin in the
 * generated registrant; keeping this tiny release stub lets a signed/release
 * APK compile without shipping the test runner or its instrumentation
 * dependencies. Debug/integration builds use the real plugin from the SDK.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {}

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
