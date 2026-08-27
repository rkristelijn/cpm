'use client';
import { useState, useEffect, forwardRef } from 'react';

// BUILD-003: async useEffect
useEffect(async () => {
  const data = await fetch('/api');
}, []);

// BUILD-006: Math.random in render
const id = <span>{Math.random()}</span>;

// BUILD-007: new Date in render  
const now = <span>{new Date().toISOString()}</span>;

// BUILD-010: context inline value
<ThemeProvider value={{ dark: true }}>

// BUILD-026: const enum export
export const enum Status { Active, Inactive }

// BUILD-040: process.exit
process.exit(1);

// BUILD-043: .default after require
const lib = require('my-lib').default;
