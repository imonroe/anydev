# Initial Context

This is a Next.js educational web application for the Initiative for Financial Decision Making (IFDM) at Stanford GSB. The app provides interactive financial calculators and tools for early-career professionals (ages 18-26) to learn about financial decision-making.

## Development Commands

### Setup and Development

```bash
yarn install              # Install dependencies (uses Yarn v1.22.22)
yarn dev                  # Start development server with Turbopack
```

### Building and Deployment

```bash
yarn build:local          # Build for local development
yarn build                # Production build with GitHub Pages setup
yarn predeploy            # Build and validate branch (must be on 1.x branch)
yarn deploy               # Deploy to GitHub Pages via gh-pages
yarn lint                 # Run ESLint
```

### Branch Requirements

- **CRITICAL**: All builds and deployments ONLY work on the `1.x` branch
- The `scripts/check-branch.js` enforces this restriction
- Main development branch is `1.x` (not `main` or `master`)

## Architecture

### Project Structure

```
app/
├── interactives/                    # Financial calculator tools
│   ├── investment-calculator/       # Investment/savings calculator
│   ├── inflation-impact-calculator/ # Inflation impact tool
│   └── present-value-calculator/    # Present value tool
├── ui/
│   ├── components/                  # Reusable UI components (shadcn/ui)
│   ├── fonts.ts                    # Font configurations
│   └── globals.css                 # Global styles and CSS variables
├── lib/
│   └── theme-toggle.tsx            # Theme switching component
├── layout.tsx                      # Root layout with global metadata
└── page.tsx                        # Home page (auto-discovery of routes)
```

### Technology Stack

- **Framework**: Next.js 15.3.3 with App Router
- **Styling**: Tailwind CSS 4.x with custom CSS variables
- **UI Components**: Custom components built on Radix UI primitives
- **Icons**: React Icons (Lucide React, React Icons)
- **TypeScript**: Full TypeScript support
- **Theme**: Light/Dark mode system with CSS variables

### Key Architectural Patterns

#### Interactive Components

All financial calculators follow a consistent pattern:

- Client-side React components with `"use client"`
- State management with `useState` and `useEffect`
- Real-time calculations based on user input
- Saving/Borrowing mode toggles
- Custom styled inputs with increment/decrement buttons
- Results displayed in styled cards

#### Theming System

- CSS variables defined in `globals.css` for theme values
- `ThemeToggle` component manages light/dark modes
- Custom color palette: `palo-verde`, `berry`, `lagunita`, `navy`, etc.
- Theme state persisted in localStorage

#### Route Discovery

The home page (`app/page.tsx`) automatically scans the `app/` directory to discover and display all available interactive tools, making development easier.

## Development Guidelines

### Adding New Interactive Tools

1. Create new directory under `app/interactives/[tool-name]/`
2. Add `page.tsx` with the calculator component
3. Follow existing patterns for state management and styling
4. Use consistent UI patterns (mode toggles, input styling, results display)
5. Tool will automatically appear on the home page

### Styling Conventions

- Use CSS variables from `globals.css` for colors
- Follow existing input styling patterns with increment/decrement buttons
- Use consistent result card layouts
- Maintain responsive design with flexbox/grid

### Component Architecture

- Use Radix UI primitives for accessible base components
- Implement client-side state for real-time calculations
- Follow existing prop and state patterns
- Use TypeScript for all components

## Deployment

### GitHub Pages Deployment

- Production site: https://ifdm-learning.stanford.edu/
- Uses static export with `next build` and `gh-pages` package
- CNAME file and `.nojekyll` automatically handled
- Embedding via iframes in MightyNetworks platform

### Deployment Process

1. Must be on `1.x` branch (enforced by script)
2. `yarn predeploy` - validates branch and builds
3. `yarn deploy` - pushes to gh-pages branch
4. GitHub Pages serves from gh-pages branch

### Embedding

Interactive tools are embedded as iframes:

```html
<iframe
  src="https://ifdm-learning.stanford.edu/interactives/investment-calculator/"
></iframe>
```

## Important Notes

- **Branch Restriction**: All development and deployment must occur on the `1.x` branch
- **Package Manager**: Project uses Yarn 1.22.22, not npm
- **Caching**: Cache-Control headers set to prevent caching issues
- **Responsive Design**: All calculators must work on mobile and desktop
- **Accessibility**: Components use proper ARIA labels and semantic markup

$ARGUMENTS
