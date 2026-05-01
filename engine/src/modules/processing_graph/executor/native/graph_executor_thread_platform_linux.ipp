/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

// cspell:ignore dbus rttime rtkit

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>

#include <gio/gio.h>
#include <pthread.h>
#include <sched.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <unistd.h>

namespace anthem {

namespace {

constexpr int rtkitDbusTimeoutMs = 2000;
constexpr int graphExecutorRealtimePriorities[] = {98, 90, 80, 70, 60, 50, 40, 30};

constexpr const char* rtkitBusName = "org.freedesktop.RealtimeKit1";
constexpr const char* rtkitObjectPath = "/org/freedesktop/RealtimeKit1";
constexpr const char* rtkitInterfaceName = "org.freedesktop.RealtimeKit1";
constexpr const char* dbusPropertiesInterfaceName = "org.freedesktop.DBus.Properties";

struct GObjectDeleter {
  void operator()(void* object) const {
    if (object != nullptr) {
      g_object_unref(object);
    }
  }
};

struct GVariantDeleter {
  void operator()(GVariant* variant) const {
    if (variant != nullptr) {
      g_variant_unref(variant);
    }
  }
};

using ScopedGDBusConnection = std::unique_ptr<GDBusConnection, GObjectDeleter>;
using ScopedGVariant = std::unique_ptr<GVariant, GVariantDeleter>;

juce::String getGErrorMessage(GError* error) {
  if (error == nullptr || error->message == nullptr) {
    return "unknown error";
  }

  return juce::String(error->message);
}

juce::String getErrorCodeMessage(int errorCode) {
  return juce::String(g_strerror(errorCode)) + " (" + juce::String(errorCode) + ")";
}

void logGraphExecutorWorkerThreadStartupFailure(int workerIndex, const juce::String& reason) {
  juce::Logger::writeToLog("Graph worker " + juce::String(workerIndex) +
                           " failed to enable Linux realtime scheduling: " + reason);
}

std::optional<juce::String> setCurrentThreadRealtimePriority(int priority) {
  sched_param scheduleParameter{};
  scheduleParameter.sched_priority = priority;

  const auto result = pthread_setschedparam(pthread_self(), SCHED_FIFO, &scheduleParameter);

  if (result == 0) {
    return std::nullopt;
  }

  return getErrorCodeMessage(result);
}

std::optional<juce::String> trySetCurrentThreadRealtimePriority() {
  juce::String result;

  for (auto priority : graphExecutorRealtimePriorities) {
    auto error = setCurrentThreadRealtimePriority(priority);

    if (!error.has_value()) {
      return std::nullopt;
    }

    if (result.isNotEmpty()) {
      result += "; ";
    }

    result += juce::String("SCHED_FIFO priority ") + juce::String(priority) +
              " failed: " + *error;
  }

  return result;
}

std::optional<int64_t> getIntValueFromVariant(GVariant* variant) {
  if (variant == nullptr) {
    return std::nullopt;
  }

  if (g_variant_is_of_type(variant, G_VARIANT_TYPE_INT32)) {
    return g_variant_get_int32(variant);
  }

  if (g_variant_is_of_type(variant, G_VARIANT_TYPE_UINT32)) {
    return g_variant_get_uint32(variant);
  }

  if (g_variant_is_of_type(variant, G_VARIANT_TYPE_INT64)) {
    return g_variant_get_int64(variant);
  }

  if (g_variant_is_of_type(variant, G_VARIANT_TYPE_UINT64)) {
    const auto value = g_variant_get_uint64(variant);

    if (value <= static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
      return static_cast<int64_t>(value);
    }
  }

  return std::nullopt;
}

std::optional<int64_t> getRtkitIntProperty(
    GDBusConnection* connection, const char* propertyName, juce::String& failureReason) {
  GError* error = nullptr;
  ScopedGVariant result(g_dbus_connection_call_sync(connection,
      rtkitBusName,
      rtkitObjectPath,
      dbusPropertiesInterfaceName,
      "Get",
      g_variant_new("(ss)", rtkitInterfaceName, propertyName),
      G_VARIANT_TYPE("(v)"),
      G_DBUS_CALL_FLAGS_NONE,
      rtkitDbusTimeoutMs,
      nullptr,
      &error));

  if (result == nullptr) {
    failureReason = juce::String(propertyName) + " could not be read: " + getGErrorMessage(error);
    g_clear_error(&error);
    return std::nullopt;
  }

  GVariant* value = nullptr;
  g_variant_get(result.get(), "(v)", &value);
  ScopedGVariant scopedValue(value);

  auto intValue = getIntValueFromVariant(scopedValue.get());

  if (!intValue.has_value()) {
    failureReason = juce::String(propertyName) + " had an unexpected D-Bus type.";
    return std::nullopt;
  }

  return intValue;
}

std::optional<juce::String> applyRtkitRealtimeRuntimeLimit(GDBusConnection* connection) {
#if defined(RLIMIT_RTTIME)
  juce::String failureReason;
  const auto rtTimeUsecMax = getRtkitIntProperty(connection, "RTTimeUSecMax", failureReason);

  if (!rtTimeUsecMax.has_value()) {
    return failureReason;
  }

  if (*rtTimeUsecMax <= 0) {
    return std::nullopt;
  }

  rlimit currentLimit{};

  if (getrlimit(RLIMIT_RTTIME, &currentLimit) != 0) {
    return juce::String("getrlimit(RLIMIT_RTTIME) failed: ") + getErrorCodeMessage(errno);
  }

  const auto targetLimit = static_cast<rlim_t>(*rtTimeUsecMax);

  if (currentLimit.rlim_cur <= targetLimit) {
    return std::nullopt;
  }

  currentLimit.rlim_cur = targetLimit;

  if (currentLimit.rlim_max != RLIM_INFINITY && currentLimit.rlim_cur > currentLimit.rlim_max) {
    currentLimit.rlim_cur = currentLimit.rlim_max;
  }

  if (setrlimit(RLIMIT_RTTIME, &currentLimit) != 0) {
    return juce::String("setrlimit(RLIMIT_RTTIME) failed: ") + getErrorCodeMessage(errno);
  }
#else
  juce::ignoreUnused(connection);
#endif

  return std::nullopt;
}

std::optional<juce::String> trySetCurrentThreadRealtimePriorityWithRtkit() {
  GError* error = nullptr;
  ScopedGDBusConnection connection(g_bus_get_sync(G_BUS_TYPE_SYSTEM, nullptr, &error));

  if (connection == nullptr) {
    const auto message = getGErrorMessage(error);
    g_clear_error(&error);
    return juce::String("could not connect to the system D-Bus: ") + message;
  }

  juce::String failureReason;
  const auto maxRealtimePriority =
      getRtkitIntProperty(connection.get(), "MaxRealtimePriority", failureReason);

  if (!maxRealtimePriority.has_value()) {
    return failureReason;
  }

  const auto requestedPriority =
      std::min<int64_t>(graphExecutorRealtimePriorities[0], *maxRealtimePriority);

  if (requestedPriority <= 0) {
    return juce::String("RTKit reported a non-positive MaxRealtimePriority: ") +
           juce::String(*maxRealtimePriority);
  }

  if (auto limitError = applyRtkitRealtimeRuntimeLimit(connection.get()); limitError.has_value()) {
    return *limitError;
  }

  const auto threadId = static_cast<guint64>(syscall(SYS_gettid));
  ScopedGVariant result(g_dbus_connection_call_sync(connection.get(),
      rtkitBusName,
      rtkitObjectPath,
      rtkitInterfaceName,
      "MakeThreadRealtime",
      g_variant_new("(tu)", threadId, static_cast<guint32>(requestedPriority)),
      G_VARIANT_TYPE("()"),
      G_DBUS_CALL_FLAGS_NONE,
      rtkitDbusTimeoutMs,
      nullptr,
      &error));

  if (result == nullptr) {
    const auto message = getGErrorMessage(error);
    g_clear_error(&error);
    return juce::String("MakeThreadRealtime failed: ") + message;
  }

  return std::nullopt;
}

class GraphExecutorWorkerThreadStartupScope final {
public:
  GraphExecutorWorkerThreadStartupScope(int workerIndex, const juce::String& threadName) {
    juce::ignoreUnused(threadName);

    if (pthread_getschedparam(pthread_self(), &originalScheduler, &originalScheduleParameter) !=
        0) {
      hasOriginalSchedule = false;
    }

    auto nativePriorityError = trySetCurrentThreadRealtimePriority();

    if (!nativePriorityError.has_value()) {
      shouldRestoreOriginalSchedule = hasOriginalSchedule;
      return;
    }

    auto rtkitError = trySetCurrentThreadRealtimePriorityWithRtkit();

    if (!rtkitError.has_value()) {
      shouldRestoreOriginalSchedule = hasOriginalSchedule;
      return;
    }

    logGraphExecutorWorkerThreadStartupFailure(
        workerIndex, *nativePriorityError + "; RTKit failed: " + *rtkitError);
  }

  ~GraphExecutorWorkerThreadStartupScope() {
    if (shouldRestoreOriginalSchedule) {
      pthread_setschedparam(pthread_self(), originalScheduler, &originalScheduleParameter);
    }
  }

  GraphExecutorWorkerThreadStartupScope(const GraphExecutorWorkerThreadStartupScope&) = delete;
  GraphExecutorWorkerThreadStartupScope& operator=(const GraphExecutorWorkerThreadStartupScope&) =
      delete;

  GraphExecutorWorkerThreadStartupScope(GraphExecutorWorkerThreadStartupScope&&) = delete;
  GraphExecutorWorkerThreadStartupScope& operator=(GraphExecutorWorkerThreadStartupScope&&) =
      delete;
private:
  int originalScheduler = SCHED_OTHER;
  sched_param originalScheduleParameter{};
  bool hasOriginalSchedule = true;
  bool shouldRestoreOriginalSchedule = false;
};

juce::Thread::Priority getGraphExecutorWorkerThreadPriority() {
  return juce::Thread::Priority::high;
}

} // namespace

} // namespace anthem
