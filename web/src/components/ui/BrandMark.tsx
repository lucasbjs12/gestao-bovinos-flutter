export function BrandMark({ size = 40 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 40 40"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <rect width="40" height="40" rx="11" fill="var(--g800)" />
      <path
        d="M12 17.5c0-1.4.9-2.5 2.2-2.9a4 4 0 0 1 7.6 0c1.3.4 2.2 1.5 2.2 2.9v6.8c0 3-2.7 5.4-6 5.4s-6-2.4-6-5.4v-6.8Z"
        fill="var(--g50)"
      />
      <circle cx="16.7" cy="20.5" r="1.15" fill="var(--g800)" />
      <circle cx="23.3" cy="20.5" r="1.15" fill="var(--g800)" />
      <path
        d="M9.5 13.5c-1.3-1.1-1.7-2.7-1.2-4.3 1.7.1 3 .9 3.8 2.2M30.5 13.5c1.3-1.1 1.7-2.7 1.2-4.3-1.7.1-3 .9-3.8 2.2"
        stroke="var(--gold)"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
