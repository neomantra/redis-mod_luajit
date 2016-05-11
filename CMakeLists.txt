# mod_luajit CMakeLists.txt

cmake_minimum_required( VERSION 2.8 )

project( mod_luajit )

# build the shared library
add_library( redis-mod_luajit SHARED mod_luajit.c )
target_link_libraries( redis-mod_luajit luajit-5.1 )

