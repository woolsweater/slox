regen-proj: .make.regen-proj

.make.regen-proj: $(shell find Sources -type f) Package.swift
	swift package generate-xcodeproj
	touch .make.regen-proj
