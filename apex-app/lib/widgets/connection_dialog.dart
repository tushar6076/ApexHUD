// lib/widgets/connection_dialog.dart
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import '../../core/config.dart';
import '../../styles/color.dart';
import '../../styles/shapes.dart';
import '../../services/audio/sfx_player.dart';
import '../../services/udp/udp_connector.dart';

class ConnectionDialogContent extends StatelessWidget {
  const ConnectionDialogContent({super.key});

  @override
  Widget build(BuildContext context) {
    final udpConnector = UdpConnector();
    final isConnected = udpConnector.isConnected;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: AppShapes.cardRadius,
              border: Border.all(
                color: isConnected
                    ? AppColors.cyberpunkCyan.withValues(alpha: 0.4)
                    : AppColors.alertRed.withValues(alpha: 0.4),
                width: AppShapes.hudBorderWidth,
              ),
              color: isConnected
                  ? const Color(0x40003333)
                  : const Color(0x40330000),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? AppColors.cyberpunkCyan
                        : AppColors.alertRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "SYSTEM ${isConnected ? "ONLINE" : "OFFLINE"}",
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConnected
                              ? AppColors.cyberpunkCyan
                              : AppColors.alertRed,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? "Target: ${Config.robotName}"
                            : "Connect to AP: APEC_ROVER",
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected
                    ? AppColors.alertRed.withValues(alpha: 0.85)
                    : AppColors.cyberpunkCyan.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppShapes.buttonRadius,
                ),
              ),
              onPressed: () async {
                SfxPlayer().playBlip();
                if (isConnected) {
                  await udpConnector.disconnect();
                  if (context.mounted) Navigator.of(context).pop();
                } else {
                  await AppSettings.openAppSettings(type: AppSettingsType.wifi);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: Text(
                isConnected ? "DISCONNECT SYSTEM" : "OPEN WI-FI SETTINGS",
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "UDP Protocol • ${Config.espIp}:${Config.udpPort}",
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}