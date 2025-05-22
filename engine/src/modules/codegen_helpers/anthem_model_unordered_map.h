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

#include <unordered_map>
#include <memory>
#include "anthem_model_base.h"

template <typename Key, typename T, typename Hash = std::hash<Key>, typename KeyEqual = std::equal_to<Key>>
class AnthemModelUnorderedMap : public AnthemModelBase {
private:
  // The internal unordered_map
  std::unordered_map<Key, T, Hash, KeyEqual> data;

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

  // Helper method to initialize a value if it's a model
  void initializeItem(T& item) {
    // Only initialize if this map itself has been initialized
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
  AnthemModelUnorderedMap() = default;

  // Copy constructor
  AnthemModelUnorderedMap(const AnthemModelUnorderedMap& other)
    : data(other.data) {}

  // Move constructor
  AnthemModelUnorderedMap(AnthemModelUnorderedMap&& other) noexcept
    : data(std::move(other.data)) {}

  // Initializer list constructor
  AnthemModelUnorderedMap(std::initializer_list<typename std::unordered_map<Key, T>::value_type> init)
    : data(init) {}

  // Assignment operators
  AnthemModelUnorderedMap& operator=(const AnthemModelUnorderedMap& other) {
    data = other.data;
    return *this;
  }

  AnthemModelUnorderedMap& operator=(AnthemModelUnorderedMap&& other) noexcept {
    data = std::move(other.data);
    return *this;
  }

  // Element access
  T& at(const Key& key) { return data.at(key); }
  const T& at(const Key& key) const { return data.at(key); }

  T& operator[](const Key& key) { 
    auto it = data.find(key);
    bool isNewElement = (it == data.end());
    T& result = data[key];
    
    // If this was a new element, initialize it
    if (isNewElement) {
      initializeItem(result);
    }
    
    return result;
  }
  
  T& operator[](Key&& key) { 
    auto it = data.find(key);
    bool isNewElement = (it == data.end());
    T& result = data[std::move(key)];
    
    // If this was a new element, initialize it
    if (isNewElement) {
      initializeItem(result);
    }
    
    return result;
  }

  // Iterators
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator begin() { return data.begin(); }
  typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator begin() const { return data.begin(); }
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator end() { return data.end(); }
  typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator end() const { return data.end(); }

  // Capacity
  bool empty() const { return data.empty(); }
  size_t size() const { return data.size(); }
  size_t max_size() const { return data.max_size(); }

  // Modifiers
  void clear() noexcept { data.clear(); }

  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> insert(const typename std::unordered_map<Key, T, Hash, KeyEqual>::value_type& value) {
    auto result = data.insert(value);
    if (result.second) {  // If insertion was successful
      initializeItem(result.first->second);
    }
    return result;
  }

  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator insert(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, const typename std::unordered_map<Key, T, Hash, KeyEqual>::value_type& value) {
    auto resultIt = data.insert(hint, value);
    initializeItem(resultIt->second);
    return resultIt;
  }

  template<typename InputIt>
  void insert(InputIt first, InputIt last) {
    // Store the initial size to check for new elements
    size_t initialSize = data.size();
    data.insert(first, last);
    
    // Only initialize elements that were actually inserted
    if (data.size() > initialSize) {
      for (auto it = first; it != last; ++it) {
        auto mapIt = data.find(it->first);
        if (mapIt != data.end()) {
          initializeItem(mapIt->second);
        }
      }
    }
  }

  void insert(std::initializer_list<typename std::unordered_map<Key, T, Hash, KeyEqual>::value_type> ilist) {
    // Store the initial size to check for new elements
    size_t initialSize = data.size();
    data.insert(ilist);
    
    // Initialize all newly inserted elements
    if (data.size() > initialSize) {
      for (const auto& item : ilist) {
        auto it = data.find(item.first);
        if (it != data.end()) {
          initializeItem(it->second);
        }
      }
    }
  }

  template<typename M>
  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> insert_or_assign(const Key& k, M&& obj) {
    auto result = data.insert_or_assign(k, std::forward<M>(obj));
    initializeItem(result.first->second);
    return result;
  }

  template<typename M>
  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> insert_or_assign(Key&& k, M&& obj) {
    auto result = data.insert_or_assign(std::move(k), std::forward<M>(obj));
    initializeItem(result.first->second);
    return result;
  }

  template<typename M>
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator insert_or_assign(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, const Key& k, M&& obj) {
    auto resultIt = data.insert_or_assign(hint, k, std::forward<M>(obj));
    initializeItem(resultIt->second);
    return resultIt;
  }

  template<typename M>
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator insert_or_assign(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, Key&& k, M&& obj) {
    auto resultIt = data.insert_or_assign(hint, std::move(k), std::forward<M>(obj));
    initializeItem(resultIt->second);
    return resultIt;
  }

  template<typename... Args>
  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> emplace(Args&&... args) {
    auto result = data.emplace(std::forward<Args>(args)...);
    if (result.second) {  // If insertion was successful
      initializeItem(result.first->second);
    }
    return result;
  }

  template<typename... Args>
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator emplace_hint(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, Args&&... args) {
    auto resultIt = data.emplace_hint(hint, std::forward<Args>(args)...);
    initializeItem(resultIt->second);
    return resultIt;
  }

  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator erase(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator pos) {
    return data.erase(pos);
  }

  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator erase(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator first, typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator last) {
    return data.erase(first, last);
  }

  size_t erase(const Key& key) {
    return data.erase(key);
  }

  void swap(AnthemModelUnorderedMap& other) noexcept {
    data.swap(other.data);
  }

  // Lookup
  size_t count(const Key& key) const { return data.count(key); }

  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator find(const Key& key) { return data.find(key); }
  typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator find(const Key& key) const { return data.find(key); }

  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator> equal_range(const Key& key) {
    return data.equal_range(key);
  }

  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator, typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator> equal_range(const Key& key) const {
    return data.equal_range(key);
  }

  // Bucket interface
  size_t bucket_count() const { return data.bucket_count(); }
  size_t max_bucket_count() const { return data.max_bucket_count(); }

  size_t bucket_size(size_t n) const { return data.bucket_size(n); }
  size_t bucket(const Key& key) const { return data.bucket(key); }

  // Hash policy
  float load_factor() const { return data.load_factor(); }
  float max_load_factor() const { return data.max_load_factor(); }
  void max_load_factor(float ml) { data.max_load_factor(ml); }

  void rehash(size_t count) { data.rehash(count); }
  void reserve(size_t count) { data.reserve(count); }

  // Observers
  Hash hash_function() const { return data.hash_function(); }
  KeyEqual key_eq() const { return data.key_eq(); }

  // Additional methods
  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    AnthemModelBase::initialize(self, parent);

    // Initialize all existing items in the map, if this map is holding Anthem
    // models
    if constexpr (isAnthemModelBase) {
      for (auto& [key, value] : data) {
        initializeItem(value);
      }
    }
  }

  // Friend functions for comparison operators
  template<typename K, typename V, typename H, typename KE>
  friend bool operator==(const AnthemModelUnorderedMap<K, V, H, KE>& lhs, const AnthemModelUnorderedMap<K, V, H, KE>& rhs);

  template<typename K, typename V, typename H, typename KE>
  friend bool operator!=(const AnthemModelUnorderedMap<K, V, H, KE>& lhs, const AnthemModelUnorderedMap<K, V, H, KE>& rhs);
};

// Comparison operators
template<typename Key, typename T, typename Hash, typename KeyEqual>
bool operator==(const AnthemModelUnorderedMap<Key, T, Hash, KeyEqual>& lhs, const AnthemModelUnorderedMap<Key, T, Hash, KeyEqual>& rhs) {
  return lhs.data == rhs.data;
}

template<typename Key, typename T, typename Hash, typename KeyEqual>
bool operator!=(const AnthemModelUnorderedMap<Key, T, Hash, KeyEqual>& lhs, const AnthemModelUnorderedMap<Key, T, Hash, KeyEqual>& rhs) {
  return lhs.data != rhs.data;
}

namespace rfl {
  // Note that unordered_map has hash and key_equal as template parameters. If
  // they are ever changed from the default, they will need to be added to the
  // Reflector.
  template <typename Key, typename T>
  struct Reflector<AnthemModelUnorderedMap<Key, T>> {
    using ReflType = std::unordered_map<Key, T>;

    static AnthemModelUnorderedMap<Key, T> to(const ReflType& value) {
      AnthemModelUnorderedMap<Key, T> result;
      result.insert(value.begin(), value.end());
      return result;
    }

    static ReflType from(const AnthemModelUnorderedMap<Key, T>& value) {
      ReflType result;
      result.insert(value.begin(), value.end());
      return result;
    }
  };
}
