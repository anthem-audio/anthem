/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#pragma once

#include <cstddef>
#include <memory>
#include <span>
#include <string_view>

namespace anthem::ipc {

/// Owns one process's mapping of a shared memory region.
class SharedMemoryRegion final {
public:
  /// Creates a zero-initialized shared memory region and maps it into the
  /// current process.
  ///
  /// Throws std::invalid_argument for an invalid size and std::system_error if
  /// the platform operation fails.
  static SharedMemoryRegion create(std::size_t size);

  /// Opens an existing shared memory region and maps it into the current
  /// process.
  ///
  /// The supplied size must exactly match the size used by the creator. Throws
  /// std::invalid_argument for invalid arguments and std::system_error if the
  /// platform operation fails.
  static SharedMemoryRegion open(std::string_view identifier, std::size_t size);

  SharedMemoryRegion(SharedMemoryRegion&&) noexcept;
  SharedMemoryRegion& operator=(SharedMemoryRegion&&) noexcept;

  SharedMemoryRegion(const SharedMemoryRegion&) = delete;
  SharedMemoryRegion& operator=(const SharedMemoryRegion&) = delete;

  ~SharedMemoryRegion();

  std::span<std::byte> bytes() noexcept;
  std::span<const std::byte> bytes() const noexcept;
  std::string_view identifier() const noexcept;

  /// Removes the name used to open this region where the platform supports
  /// that operation. Existing mappings remain valid.
  ///
  /// POSIX regions are unlinked. Windows removes named mappings automatically
  /// after the final mapped handle closes, so this is a no-op there.
  void removeIdentifier();
private:
  class Impl;

  explicit SharedMemoryRegion(std::unique_ptr<Impl> impl);

  std::unique_ptr<Impl> impl;
};

} // namespace anthem::ipc
