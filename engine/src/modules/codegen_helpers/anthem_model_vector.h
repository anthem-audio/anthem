/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#pragma once

#include <vector>
#include <memory>
#include <iterator>

#include "anthem_model_base.h"

template <typename T>
class AnthemModelVector : public AnthemModelBase {
private:
  // The internal vector
  std::vector<T> data;

  // Helper to check if T is std::shared_ptr<U> where U derives from AnthemModelBase
  template <typename U>
  struct IsSharedPtrOfAnthemModelBase : std::false_type {};

  template <typename U>
  struct IsSharedPtrOfAnthemModelBase<std::shared_ptr<U>>
      : std::is_base_of<AnthemModelBase, U> {};

  // Helper to check if T is std::optional<std::shared_ptr<U>> where U derives from AnthemModelBase
  template <typename U>
  struct IsOptionalSharedPtrOfAnthemModelBase : std::false_type {};

  template <typename U>
  struct IsOptionalSharedPtrOfAnthemModelBase<std::optional<std::shared_ptr<U>>>
      : std::is_base_of<AnthemModelBase, U> {};

  static constexpr bool isAnthemModelBase =
      IsSharedPtrOfAnthemModelBase<T>::value ||
          IsOptionalSharedPtrOfAnthemModelBase<T>::value;

  // Helper method to initialize a single item if the vector is initialized
  void initializeItem(T& item) {
    // Only initialize if this vector itself has been initialized
    auto selfPtr = this->self.lock();
    if (!selfPtr) {
      return;
    }

    if constexpr (IsOptionalSharedPtrOfAnthemModelBase<T>::value) {
      if (item && *item) {  // Check if optional has value AND the shared_ptr is not null
        (*item)->initialize(item, selfPtr);
      }
    } else if constexpr (IsSharedPtrOfAnthemModelBase<T>::value) {
      if (item) {  // Check if the shared_ptr is not null
        item->initialize(item, selfPtr);
      }
    }
  }

public:
  // Constructors
  AnthemModelVector() : data() {}

  // Copy constructor
  AnthemModelVector(const AnthemModelVector& other)
    : data(other.data) {}

  // Move constructor
  AnthemModelVector(AnthemModelVector&& other) noexcept
    : data(std::move(other.data)) {}

  // Copy assignment operator
  AnthemModelVector& operator=(const AnthemModelVector& other) {
    data = other.data;
    return *this;
  }

  // Move assignment operator
  AnthemModelVector& operator=(AnthemModelVector&& other) noexcept {
    data = std::move(other.data);
    return *this;
  }

  // Range constructor
  template<typename InputIt>
  AnthemModelVector(InputIt first, InputIt last)
    : data(first, last) {}

  // Access operators
  T& operator[](size_t index) { return data[index]; }
  const T& operator[](size_t index) const { return data[index]; }

  // At method with bounds checking
  T& at(size_t index) { return data.at(index); }
  const T& at(size_t index) const { return data.at(index); }

  // Front and back methods
  T& front() { return data.front(); }
  const T& front() const { return data.front(); }
  T& back() { return data.back(); }
  const T& back() const { return data.back(); }

  // Size and capacity methods
  size_t size() const { return data.size(); }
  size_t capacity() const { return data.capacity(); }
  bool empty() const { return data.empty(); }
  void reserve(size_t new_cap) { data.reserve(new_cap); }
  
  void resize(size_t count) { 
    size_t oldSize = data.size();
    data.resize(count); 
    
    // Initialize new elements if expanding
    if (count > oldSize) {
      for (size_t i = oldSize; i < count; ++i) {
        initializeItem(data[i]);
      }
    }
  }
  
  void resize(size_t count, const T& value) { 
    size_t oldSize = data.size();
    data.resize(count, value); 
    
    // Initialize new elements if expanding
    if (count > oldSize) {
      for (size_t i = oldSize; i < count; ++i) {
        initializeItem(data[i]);
      }
    }
  }

  // Modifier methods
  void push_back(const T& value) { 
    data.push_back(value);
    initializeItem(data.back());
  }
  
  void push_back(T&& value) { 
    data.push_back(std::move(value));
    initializeItem(data.back());
  }

  template<typename... Args>
  T& emplace_back(Args&&... args) {
    T& item = data.emplace_back(std::forward<Args>(args)...);
    initializeItem(item);
    return item;
  }

  void pop_back() { data.pop_back(); }

  void clear() { data.clear(); }

  // Insert methods
  typename std::vector<T>::iterator insert(typename std::vector<T>::const_iterator pos, const T& value) {
    auto it = data.insert(pos, value);
    initializeItem(*it);
    return it;
  }

  typename std::vector<T>::iterator insert(typename std::vector<T>::const_iterator pos, T&& value) {
    auto it = data.insert(pos, std::move(value));
    initializeItem(*it);
    return it;
  }

  typename std::vector<T>::iterator insert(typename std::vector<T>::const_iterator pos, size_t count, const T& value) {
    auto it = data.insert(pos, count, value);
    // Initialize all newly inserted elements
    for (size_t i = 0; i < count; ++i) {
      initializeItem(*(it + i));
    }
    return it;
  }

  template<typename InputIt>
  typename std::vector<T>::iterator insert(typename std::vector<T>::const_iterator pos, InputIt first, InputIt last) {
    auto oldSize = data.size();
    auto it = data.insert(pos, first, last);
    // Calculate the distance from it to the end of the newly inserted elements
    auto count = std::distance(first, last);
    // Initialize all newly inserted elements
    for (size_t i = 0; i < count; ++i) {
      initializeItem(*(it + i));
    }
    return it;
  }

  typename std::vector<T>::iterator insert(typename std::vector<T>::const_iterator pos, std::initializer_list<T> ilist) {
    auto it = data.insert(pos, ilist);
    // Initialize all newly inserted elements
    for (size_t i = 0; i < ilist.size(); ++i) {
      initializeItem(*(it + i));
    }
    return it;
  }

  // Emplace method
  template<typename... Args>
  typename std::vector<T>::iterator emplace(typename std::vector<T>::const_iterator pos, Args&&... args) {
    auto it = data.emplace(pos, std::forward<Args>(args)...);
    initializeItem(*it);
    return it;
  }

  // Erase methods
  typename std::vector<T>::iterator erase(typename std::vector<T>::const_iterator pos) {
    return data.erase(pos);
  }

  typename std::vector<T>::iterator erase(typename std::vector<T>::const_iterator first, typename std::vector<T>::const_iterator last) {
    return data.erase(first, last);
  }

  // Swap method
  void swap(AnthemModelVector& other) noexcept(std::is_nothrow_swappable_v<std::vector<T>>) {
    data.swap(other.data);
  }

  // Iterator access
  typename std::vector<T>::iterator begin() { return data.begin(); }
  typename std::vector<T>::iterator end() { return data.end(); }
  typename std::vector<T>::const_iterator begin() const { return data.begin(); }
  typename std::vector<T>::const_iterator end() const { return data.end(); }
  typename std::vector<T>::const_iterator cbegin() const { return data.cbegin(); }
  typename std::vector<T>::const_iterator cend() const { return data.cend(); }
  typename std::vector<T>::reverse_iterator rbegin() { return data.rbegin(); }
  typename std::vector<T>::reverse_iterator rend() { return data.rend(); }
  typename std::vector<T>::const_reverse_iterator rbegin() const { return data.rbegin(); }
  typename std::vector<T>::const_reverse_iterator rend() const { return data.rend(); }

  // Data access
  T* data_ptr() noexcept { return data.data(); }
  const T* data_ptr() const noexcept { return data.data(); }

  // Comparison operators
  bool operator==(const AnthemModelVector& other) const { return data == other.data; }
  bool operator!=(const AnthemModelVector& other) const { return data != other.data; }

  // Additional methods
  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    AnthemModelBase::initialize(self, parent);

    // Initialize all elements in the vector, if applicable
    if constexpr (isAnthemModelBase) {
      for (auto& item : data) {
        initializeItem(item);
      }
    }
  }
};

namespace rfl {
  template <typename T>
  struct Reflector<AnthemModelVector<T>> {
    using ReflType = std::vector<T>;

    static AnthemModelVector<T> to(const ReflType& value) {
      // Unfortunately, we have to copy here. We use shared_ptr for nontrivial
      // data in collections, so this is mostly fine, but not optimal.
      return AnthemModelVector<T>(value.begin(), value.end());
    }

    static ReflType from(const AnthemModelVector<T>& value) {
      return ReflType(value.begin(), value.end());
    }
  };
}
