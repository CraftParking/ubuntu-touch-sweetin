cmake_minimum_required(VERSION 3.5)
project(craftparking-update-panel)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 11)

find_package(Qt5 REQUIRED COMPONENTS Qml Quick Network DBus)

add_library(CraftparkingUpdatePanel MODULE
  plugin.cpp
  update.cpp
  plugin.h
  update.h
)

target_link_libraries(CraftparkingUpdatePanel
  Qt5::Qml Qt5::Quick Qt5::Network Qt5::DBus
)
