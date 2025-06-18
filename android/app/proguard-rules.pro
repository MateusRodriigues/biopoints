# Flutter specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Manter anotações, assinaturas de métodos genéricos, classes internas e métodos de fechamento.
# Crucial para evitar erros de TypeToken com Gson/Reflection em plugins.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Regras para flutter_local_notifications (e suas dependências que podem usar Gson/Reflection)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationRepeatInterval { *; }
-keep class com.dexterous.flutterlocalnotifications.Day { *; }
-keep class com.dexterous.flutterlocalnotifications.Time { *; }
-keep class com.dexterous.flutterlocalnotifications.models.NotificationDetails { *; }
-keep class com.dexterous.flutterlocalnotifications.models.ScheduledNotification { *; }

# Regras comuns para Gson (se for usado por alguma dependência nativa dos plugins)
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.Gson { *; }
-keep class com.google.gson.stream.** { *; }

# Para Java 8+ API desugaring, geralmente não são necessárias regras específicas aqui
# se o coreLibraryDesugaring estiver habilitado corretamente no build.gradle.

# Se você usa outros plugins que podem ser afetados pela minificação,
# adicione as regras específicas deles aqui, conforme a documentação dos plugins.
# Exemplo:
# -keep class com.example.anotherplugin.** { *; }