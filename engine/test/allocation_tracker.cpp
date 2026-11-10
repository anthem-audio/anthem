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

#include "allocation_tracker.h"

#include <cstdlib>
#include <new>

#ifdef _WIN32
#include <malloc.h>
#endif

namespace {
void recordAllocation() noexcept {
  if (anthem::test::trackingAllocations)
    ++anthem::test::allocationCount;
}
} // namespace

void* operator new(std::size_t size) {
  recordAllocation();
  if (auto* result = std::malloc(size == 0 ? 1 : size))
    return result;
  throw std::bad_alloc();
}
void* operator new[](std::size_t size) {
  return ::operator new(size);
}
void operator delete(void* pointer) noexcept {
  if (pointer != nullptr && anthem::test::trackingAllocations)
    ++anthem::test::deallocationCount;
  std::free(pointer);
}
void operator delete[](void* pointer) noexcept {
  ::operator delete(pointer);
}
void operator delete(void* pointer, std::size_t) noexcept {
  ::operator delete(pointer);
}
void operator delete[](void* pointer, std::size_t) noexcept {
  ::operator delete(pointer);
}

void* operator new(std::size_t size, std::align_val_t alignment) {
  recordAllocation();
  const auto bytes = static_cast<std::size_t>(alignment);
#ifdef _WIN32
  auto* result = _aligned_malloc(size == 0 ? bytes : size, bytes);
#else
  void* result = nullptr;
  if (posix_memalign(&result, bytes, size == 0 ? 1 : size) != 0)
    result = nullptr;
#endif
  if (result != nullptr)
    return result;
  throw std::bad_alloc();
}
void* operator new[](std::size_t size, std::align_val_t alignment) {
  return ::operator new(size, alignment);
}
void operator delete(void* pointer, std::align_val_t) noexcept {
  if (pointer != nullptr && anthem::test::trackingAllocations)
    ++anthem::test::deallocationCount;
#ifdef _WIN32
  _aligned_free(pointer);
#else
  std::free(pointer);
#endif
}
void operator delete[](void* pointer, std::align_val_t alignment) noexcept {
  ::operator delete(pointer, alignment);
}
void operator delete(void* pointer, std::size_t, std::align_val_t alignment) noexcept {
  ::operator delete(pointer, alignment);
}
void operator delete[](void* pointer, std::size_t, std::align_val_t alignment) noexcept {
  ::operator delete(pointer, alignment);
}
