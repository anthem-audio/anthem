/*
  Copyright (C) 2024 Joshua Wade

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

class AnthemModelBase; // Forward declaration if necessary

template <typename Key, typename T, typename Hash = std::hash<Key>, typename KeyEqual = std::equal_to<Key>>
class AnthemModelUnorderedMap {
public:
  // Public weak pointer to parent, defaults to being unassigned
  // std::weak_ptr<AnthemModelBase> parent;

private:
  // The internal unordered_map
  std::unordered_map<Key, T, Hash, KeyEqual> data;

public:
  // Constructors
  AnthemModelUnorderedMap() = default;

  // Copy constructor
  AnthemModelUnorderedMap(const AnthemModelUnorderedMap& other)
    : /*parent(other.parent),*/ data(other.data) {}

  // Move constructor
  AnthemModelUnorderedMap(AnthemModelUnorderedMap&& other) noexcept
    : /*parent(std::move(other.parent)),*/ data(std::move(other.data)) {}

  // Initializer list constructor
  AnthemModelUnorderedMap(std::initializer_list<typename std::unordered_map<Key, T>::value_type> init)
    : data(init) {}

  // Assignment operators
  AnthemModelUnorderedMap& operator=(const AnthemModelUnorderedMap& other) {
    // parent = other.parent;
    data = other.data;
    return *this;
  }

  AnthemModelUnorderedMap& operator=(AnthemModelUnorderedMap&& other) noexcept {
    // parent = std::move(other.parent);
    data = std::move(other.data);
    return *this;
  }

  // Element access
  T& at(const Key& key) { return data.at(key); }
  const T& at(const Key& key) const { return data.at(key); }

  T& operator[](const Key& key) { return data[key]; }
  T& operator[](Key&& key) { return data[std::move(key)]; }

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
    return data.insert(value);
  }

  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator insert(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, const typename std::unordered_map<Key, T, Hash, KeyEqual>::value_type& value) {
    return data.insert(hint, value);
  }

  template<typename InputIt>
  void insert(InputIt first, InputIt last) {
    data.insert(first, last);
  }

  void insert(std::initializer_list<typename std::unordered_map<Key, T, Hash, KeyEqual>::value_type> ilist) {
    data.insert(ilist);
  }

  template<typename M>
  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> insert_or_assign(const Key& k, M&& obj) {
    return data.insert_or_assign(k, std::forward<M>(obj));
  }

  template<typename M>
  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> insert_or_assign(Key&& k, M&& obj) {
    return data.insert_or_assign(std::move(k), std::forward<M>(obj));
  }

  template<typename M>
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator insert_or_assign(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, const Key& k, M&& obj) {
    return data.insert_or_assign(hint, k, std::forward<M>(obj));
  }

  template<typename M>
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator insert_or_assign(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, Key&& k, M&& obj) {
    return data.insert_or_assign(hint, std::move(k), std::forward<M>(obj));
  }

  template<typename... Args>
  std::pair<typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator, bool> emplace(Args&&... args) {
    return data.emplace(std::forward<Args>(args)...);
  }

  template<typename... Args>
  typename std::unordered_map<Key, T, Hash, KeyEqual>::iterator emplace_hint(typename std::unordered_map<Key, T, Hash, KeyEqual>::const_iterator hint, Args&&... args) {
    return data.emplace_hint(hint, std::forward<Args>(args)...);
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
    // parent.swap(other.parent);
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
  // void myMethod() {
    // Your implementation here
  // }

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
