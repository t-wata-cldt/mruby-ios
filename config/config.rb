APP_NAME = 'TestApp'
PRODUCT_BUNDLE_IDENTIFIER = 'test'
LANGUAGE = 'ja'

# 依存ファイルバージョン
MRUBY_VERSION = '1.2.0'
LIBUV_VERSION = '1.10.2'
IOS_SIM_VERSION = '5.0.13'
IOS_DEPLOY_VERSION = '1.9.0'

# なんか開発がgithubベースになってからタグが...
LIBFFI_VERSION = :master

MRBGEMS = %w(
mruby-cfunc mruby-cocoa mobiruby-common mruby-json mruby-digest mruby-pack
mruby-sqlite3 mruby-uv mruby-http)

CORE_MRBGEMS = %w(
mruby-sprintf mruby-print mruby-math mruby-time mruby-struct
mruby-enum-ext mruby-string-ext mruby-numeric-ext mruby-array-ext
mruby-hash-ext mruby-range-ext mruby-proc-ext mruby-symbol-ext
mruby-random mruby-object-ext mruby-objectspace mruby-fiber
mruby-enumerator mruby-enum-lazy mruby-toplevel-ext mruby-kernel-ext
mruby-compiler)

FRAMEWORKS = %w[QuartzCore AVFoundation SystemConfiguration UIKit Foundation CoreGraphics]

PLATFORM_IOS = "#{`xcode-select -print-path`.strip}/Platforms/iPhoneOS.platform"
PLATFORM_IOS_SIM = "#{`xcode-select -print-path`.strip}/Platforms/iPhoneSimulator.platform"

sdk_version_regex = /^iPhoneOS(\d+).(\d+).sdk$/
SDK_IOS_VERSION = Dir.entries("#{PLATFORM_IOS}/Developer/SDKs/").find{|v| v =~ sdk_version_regex } && "#{$1}.#{$2}"

MIN_IOS_VERSION = "8.0"
MIN_IOS_VERSION_FLAG = '-D__IPHONE_OS_VERSION_MIN_REQUIRED=__IPHONE_8_0'

BASE_DIR = File.absolute_path "#{File.dirname(__FILE__)}/.."
BUILD_DIR = "#{BASE_DIR}/build"
MRUBY_BUILD_DIR = "#{BUILD_DIR}/mruby"
MRUBY_CONFIG = File.absolute_path "#{BASE_DIR}/config/mruby_config.rb"
MRBC_EXEC = "#{BUILD_DIR}/mruby/host/bin/mrbc"

IOS_SDK = "#{PLATFORM_IOS}/Developer/SDKs/iPhoneOS#{SDK_IOS_VERSION}.sdk"
IOS_SIM_SDK = "#{PLATFORM_IOS_SIM}/Developer/SDKs/iPhoneSimulator#{SDK_IOS_VERSION}.sdk"

APP_PATH = "#{BUILD_DIR}/ios/#{APP_NAME}.app"
LIBMRUBY = "#{BUILD_DIR}/libmruby.a"

# makeなどで同時実行するタスク数
BUILD_TASKS = 4

def ios_sdk target
  case target
  when :dev; sdk = IOS_SDK
  when :sim; sdk = IOS_SIM_SDK
  end
end

def ios_cc target, arch
  "ccache #{`Xcrun -find -sdk #{ios_sdk target} cc`.strip} -arch #{arch} -std=gnu11"
end

def ios_cxx target, arch
  "ccache #{`xcrun -find -sdk #{ios_sdk target} c++`.strip} -arch #{arch} -std=gnu++11"
end

# ここらへんは以下のリンクを参考に
# http://www.srplab.com/en/files/others/compile/cross_compiling_python_for_ios.html
BUILD_ARCHS = {
  dev: [:armv7, :armv7s], # , :arm64
  sim: [:i386], # , :x86_64
}

def to_host_arch name
  { armv7: :arm, armv7s: :arm, arm64: :aarch64 }[name] || name
end

def ios_cflags target, arch
  ret = []
  case target
  when :dev; ret << %Q[-miphoneos-version-min=#{MIN_IOS_VERSION}]
  when :sim; ret << %Q[-mios-simulator-version-min=#{MIN_IOS_VERSION}]
  end

  ret << %Q[-isysroot #{ios_sdk target} #{MIN_IOS_VERSION_FLAG}]
  ret << %Q[-fmessage-length=0 -fpascal-strings -fexceptions -fasm-blocks -gdwarf-2]
  ret << %Q[-fobjc-abi-version=2]

  ret.join(' ')
end
