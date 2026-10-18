# Android SDK / NDK and JDK for HyprMobile (Tauri 2 Android builds)
set -gx ANDROID_HOME $HOME/Android/Sdk
set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk
if test -d $ANDROID_HOME/ndk
    set -l ndk (path sort $ANDROID_HOME/ndk/* | tail -n 1)
    test -n "$ndk"; and set -gx NDK_HOME $ndk
end
fish_add_path -g $ANDROID_HOME/cmdline-tools/latest/bin $ANDROID_HOME/platform-tools
