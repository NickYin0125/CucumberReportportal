# frozen_string_literal: true

@component:isolated @owner:second-feature
Feature: M3C second feature isolation

  @team:second-feature
  Scenario: Attributes stay within their feature
    Given an M3C attribute case "second-feature"
