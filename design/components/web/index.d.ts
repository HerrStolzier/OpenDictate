import type * as React from 'react';

/** The five app states Blink acts out. */
export type BlinkState = 'bereit' | 'hoert' | 'schreibt' | 'eingefuegt' | 'hoppla';

export interface BlinkProps {
  /** Which app state Blink shows. Default 'bereit'. */
  state?: BlinkState;
  /** Height in px; width follows the pixel grid. Default 200. */
  size?: number;
  /** Stop all motion (screenshots, print, tiny sizes). */
  still?: boolean;
  /** Always use the full 44 x 50 stage, so states line up in a row. */
  framed?: boolean;
  /** Phosphor glow from the `glow` token. Hero use only. */
  glow?: boolean;
  /** Accessible name; defaults to "Blink <state>". */
  label?: string;
  className?: string;
}
export declare function Blink(props: BlinkProps): React.ReactElement;

export interface WordmarkProps {
  /** Font size in px; Blink scales with it on the font's own pixel grid. Default 48. */
  size?: number;
  /** Stop Blink blinking. */
  still?: boolean;
}
export declare function Wordmark(props: WordmarkProps): React.ReactElement;

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** primary = signal fill, once per view; secondary = everything else. Default 'primary'. */
  variant?: 'primary' | 'secondary';
}
export declare function Button(props: ButtonProps): React.ReactElement;

export interface KeycapProps {
  /** The key drawn as a pixel glyph. Default 'option'. */
  glyph?: 'option' | 'shift' | 'space';
}
export declare function Keycap(props: KeycapProps): React.ReactElement;

export interface MeterProps {
  /** One level per column, 0-10. Columns 7-8 turn warn, 9-10 rec. Default: a demo curve. */
  levels?: number[];
  /** Top cell of each column flickers. Default true. */
  live?: boolean;
  /** Accessible name. Default "Aufnahmepegel". */
  label?: string;
}
export declare function Meter(props: MeterProps): React.ReactElement;

export interface ProgressProps {
  /** 0-1. Default 0.65. */
  value?: number;
  /** Number of pixel cells. Default 14. */
  cells?: number;
  /** The next cell blinks while work is running. Default true. */
  busy?: boolean;
  /** Accessible name. Default "Fortschritt". */
  label?: string;
}
export declare function Progress(props: ProgressProps): React.ReactElement;

export interface PixelIconProps {
  name: 'rec' | 'check' | 'error' | 'prompt';
  /** Rendered size in px; keep multiples of 12. Default 36. */
  size?: number;
  /** Colour; defaults to rec for rec/error, signal for check/prompt. */
  tone?: 'signal' | 'rec' | 'ink' | 'muted';
  /** Accessible name; pass "" when a visible word sits next to it. */
  label?: string;
}
export declare function PixelIcon(props: PixelIconProps): React.ReactElement;

declare global {
  interface Window {
    OpenDictate: {
      Blink: typeof Blink;
      Wordmark: typeof Wordmark;
      Button: typeof Button;
      Keycap: typeof Keycap;
      Meter: typeof Meter;
      Progress: typeof Progress;
      PixelIcon: typeof PixelIcon;
    };
  }
}
