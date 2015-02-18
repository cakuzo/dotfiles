#!/bin/bash
mysqlcheck --all-databases
mysqlcheck --all-databases -o
mysqlcheck --all-databases --auto-repair
mysqlcheck --all-databases --analyze
