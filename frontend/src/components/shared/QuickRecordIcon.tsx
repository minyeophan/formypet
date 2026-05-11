import { Circle, Ellipse, Line, Path, Rect, Svg } from 'react-native-svg';
import AppText from './AppText';

type QuickRecordIconProps = {
  typeId: string;
  fallback: string;
  size?: number;
  muted?: boolean;
};

const stroke = '#4A4A4A';
const mutedStroke = '#9B948B';

export default function QuickRecordIcon({ typeId, fallback, size = 32, muted = false }: QuickRecordIconProps) {
  const lineColor = muted ? mutedStroke : stroke;
  const opacity = muted ? 0.62 : 1;

  switch (typeId) {
    case 'meal':
      return (
        <Svg width={size} height={size} viewBox="0 0 48 48" style={{ opacity }}>
          <Line x1={18} y1={16} x2={28} y2={7} stroke={lineColor} strokeWidth={4} strokeLinecap="round" />
          <Path
            d="M12 21h24v7c0 5.7-4.6 10-12 10s-12-4.3-12-10v-7Z"
            fill="#FFF8F0"
            stroke={lineColor}
            strokeWidth={3.4}
            strokeLinejoin="round"
          />
          <Path
            d="M12 25h24"
            fill="none"
            stroke="#F3A1A8"
            strokeWidth={3.4}
            strokeLinecap="round"
          />
          <Path
            d="M10 21h28"
            fill="none"
            stroke={lineColor}
            strokeWidth={3.4}
            strokeLinecap="round"
          />
          <Path
            d="M17 38h14"
            fill="none"
            stroke={lineColor}
            strokeWidth={3.4}
            strokeLinecap="round"
          />
        </Svg>
      );
    case 'water':
      return (
        <Svg width={size} height={size} viewBox="0 0 48 48" style={{ opacity }}>
          <Path
            d="M12 27c1.2 7.2 5.7 11 12 11s10.8-3.8 12-11H12Z"
            fill="#CDEFFF"
            stroke={lineColor}
            strokeWidth={3.2}
            strokeLinejoin="round"
          />
          <Path
            d="M15 27c2.3-2.4 5.3-3.7 9-3.7s6.7 1.3 9 3.7"
            fill="none"
            stroke={lineColor}
            strokeWidth={3.2}
            strokeLinecap="round"
          />
          <Path
            d="M24 9c-3.6 4.4-5.4 7.5-5.4 10.1a5.4 5.4 0 0 0 10.8 0C29.4 16.5 27.6 13.4 24 9Z"
            fill="#7ED6E6"
            stroke={lineColor}
            strokeWidth={3.2}
            strokeLinejoin="round"
          />
          <Ellipse cx={24} cy={37.5} rx={8} ry={1.4} fill="#EAF8F8" />
        </Svg>
      );
    case 'walk':
      return (
        <Svg width={size} height={size} viewBox="0 0 48 48" style={{ opacity }}>
          <Path
            d="M12 30c5-2 7.8-5.9 8.4-11.8"
            fill="none"
            stroke={lineColor}
            strokeWidth={3.2}
            strokeLinecap="round"
          />
          <Rect
            x={19}
            y={10}
            width={14}
            height={10}
            rx={5}
            fill="#BDEBD9"
            stroke={lineColor}
            strokeWidth={3.2}
          />
          <Path
            d="M32 15c5.7.5 8.5 3.7 8.5 8.4 0 5.6-4.8 9.6-11.5 9.6H18"
            fill="none"
            stroke={lineColor}
            strokeWidth={3.2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <Circle cx={15} cy={36} r={3.3} fill="#F4A460" stroke={lineColor} strokeWidth={2.6} />
          <Circle cx={24} cy={39} r={3.3} fill="#F4A460" stroke={lineColor} strokeWidth={2.6} />
          <Circle cx={33} cy={36} r={3.3} fill="#F4A460" stroke={lineColor} strokeWidth={2.6} />
        </Svg>
      );
    default:
      return (
        <AppText style={{ fontSize: Math.round(size * 0.78), opacity: muted ? 0.48 : 1 }}>
          {fallback}
        </AppText>
      );
  }
}
