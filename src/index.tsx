/* eslint-disable no-undef */
import type { Frame } from 'react-native-vision-camera';

export type BoundingFrame = {
  x: number;
  y: number;
  width: number;
  height: number;
  boundingCenterX: number;
  boundingCenterY: number;
};
export type Point = { x: number; y: number };

export type TextElement = {
  text: string;
  frame: BoundingFrame;
  cornerPoints: Point[];
};

export type TextLine = {
  text: string;
  elements: TextElement[];
  frame: BoundingFrame;
  recognizedLanguages: string[];
  cornerPoints: Point[];
};

export type TextBlock = {
  text: string;
  lines: TextLine[];
  frame: BoundingFrame;
  recognizedLanguages: string[];
  cornerPoints: Point[];
};

export type Text = {
  text: string;
  blocks: TextBlock[];
};

export type OCRFrame = {
  result: Text;
};

export interface PreviewSize {
  widht?: number;
  height?: number;
}

/**
 * Scans OCR.
 */

export function scanOCR(frame: Frame, previewSize: PreviewSize): OCRFrame {
  'worklet';
  // @ts-ignore
  return __scanOCR(frame, previewSize);
}
