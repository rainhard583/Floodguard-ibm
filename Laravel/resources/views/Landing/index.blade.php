<style>
    /* =========================================================
       FLOOD RESILIENCE — MOTION ENHANCEMENT
       Hanya menambahkan animasi.
       Tidak mengubah struktur/content landing page.
       ========================================================= */

    html {
        scroll-behavior: smooth;
    }

    /* ---------------------------------------------------------
       PAGE LOAD
       --------------------------------------------------------- */

    body {
        animation: pageEnter 0.9s cubic-bezier(.22, 1, .36, 1) both;
    }

    @keyframes pageEnter {
        from {
            opacity: 0;
        }

        to {
            opacity: 1;
        }
    }

    /* ---------------------------------------------------------
       SCROLL REVEAL
       --------------------------------------------------------- */

    .motion-reveal {
        opacity: 0;
        transform: translateY(45px);
        transition:
            opacity 0.9s cubic-bezier(.22, 1, .36, 1),
            transform 0.9s cubic-bezier(.22, 1, .36, 1);
        will-change: opacity, transform;
    }

    .motion-reveal.motion-visible {
        opacity: 1;
        transform: translateY(0);
    }

    .motion-left {
        opacity: 0;
        transform: translateX(-50px);
        transition:
            opacity 0.9s cubic-bezier(.22, 1, .36, 1),
            transform 0.9s cubic-bezier(.22, 1, .36, 1);
    }

    .motion-left.motion-visible {
        opacity: 1;
        transform: translateX(0);
    }

    .motion-right {
        opacity: 0;
        transform: translateX(50px);
        transition:
            opacity 0.9s cubic-bezier(.22, 1, .36, 1),
            transform 0.9s cubic-bezier(.22, 1, .36, 1);
    }

    .motion-right.motion-visible {
        opacity: 1;
        transform: translateX(0);
    }

    /* ---------------------------------------------------------
       STAGGER
       --------------------------------------------------------- */

    .motion-stagger > * {
        opacity: 0;
        transform: translateY(25px);
        transition:
            opacity 0.7s cubic-bezier(.22, 1, .36, 1),
            transform 0.7s cubic-bezier(.22, 1, .36, 1);
    }

    .motion-stagger.motion-visible > *:nth-child(1) {
        transition-delay: 0.05s;
    }

    .motion-stagger.motion-visible > *:nth-child(2) {
        transition-delay: 0.12s;
    }

    .motion-stagger.motion-visible > *:nth-child(3) {
        transition-delay: 0.19s;
    }

    .motion-stagger.motion-visible > *:nth-child(4) {
        transition-delay: 0.26s;
    }

    .motion-stagger.motion-visible > *:nth-child(5) {
        transition-delay: 0.33s;
    }

    .motion-stagger.motion-visible > *:nth-child(6) {
        transition-delay: 0.40s;
    }

    .motion-stagger.motion-visible > * {
        opacity: 1;
        transform: translateY(0);
    }

    /* ---------------------------------------------------------
       FLOATING EFFECT
       --------------------------------------------------------- */

    .motion-float {
        animation: gentleFloat 5s ease-in-out infinite;
        will-change: transform;
    }

    @keyframes gentleFloat {
        0%,
        100% {
            transform: translateY(0);
        }

        50% {
            transform: translateY(-10px);
        }
    }

    .motion-float-slow {
        animation: gentleFloatSlow 8s ease-in-out infinite;
        will-change: transform;
    }

    @keyframes gentleFloatSlow {
        0%,
        100% {
            transform: translate3d(0, 0, 0);
        }

        50% {
            transform: translate3d(0, -15px, 0);
        }
    }

    /* ---------------------------------------------------------
       GLOW / BREATHING
       --------------------------------------------------------- */

    .motion-glow {
        animation: breathingGlow 3.5s ease-in-out infinite;
    }

    @keyframes breathingGlow {
        0%,
        100% {
            filter: drop-shadow(0 0 0 rgba(20, 184, 166, 0));
        }

        50% {
            filter: drop-shadow(0 0 18px rgba(20, 184, 166, 0.22));
        }
    }

    /* ---------------------------------------------------------
       BUTTON
       --------------------------------------------------------- */

    .motion-button {
        position: relative;
        overflow: hidden;
        isolation: isolate;
        transition:
            transform 0.25s ease,
            box-shadow 0.25s ease,
            filter 0.25s ease;
    }

    .motion-button::before {
        content: "";
        position: absolute;
        inset: 0;
        background: linear-gradient(
            110deg,
            transparent 20%,
            rgba(255, 255, 255, 0.20) 45%,
            transparent 70%
        );
        transform: translateX(-120%);
        transition: transform 0.65s ease;
        pointer-events: none;
        z-index: -1;
    }

    .motion-button:hover {
        transform: translateY(-3px);
        filter: brightness(1.08);
        box-shadow:
            0 12px 30px rgba(0, 0, 0, 0.20);
    }

    .motion-button:hover::before {
        transform: translateX(120%);
    }

    .motion-button:active {
        transform: translateY(0) scale(0.97);
    }

    /* ---------------------------------------------------------
       CARD HOVER
       --------------------------------------------------------- */

    .motion-card {
        transition:
            transform 0.45s cubic-bezier(.22, 1, .36, 1),
            box-shadow 0.45s ease,
            border-color 0.45s ease;
        will-change: transform;
    }

    .motion-card:hover {
        transform: translateY(-8px);
        box-shadow:
            0 22px 55px rgba(0, 0, 0, 0.18);
    }

    /* ---------------------------------------------------------
       IMAGE / VISUAL HOVER
       --------------------------------------------------------- */

    .motion-visual {
        transition:
            transform 0.8s cubic-bezier(.22, 1, .36, 1);
    }

    .motion-visual:hover {
        transform: scale(1.025);
    }

    /* ---------------------------------------------------------
       WATER / GRAPH PULSE
       --------------------------------------------------------- */

    .motion-water {
        animation:
            waterPulse 4s ease-in-out infinite,
            waterGlow 3s ease-in-out infinite alternate;
        transform-origin: center;
    }

    @keyframes waterPulse {
        0%,
        100% {
            transform: translateY(0);
        }

        50% {
            transform: translateY(-4px);
        }
    }

    @keyframes waterGlow {
        from {
            opacity: 0.72;
        }

        to {
            opacity: 1;
        }
    }

    /* ---------------------------------------------------------
       STATUS DOT
       --------------------------------------------------------- */

    .motion-pulse {
        animation: statusPulse 2s ease-in-out infinite;
    }

    @keyframes statusPulse {
        0%,
        100% {
            transform: scale(1);
            opacity: 1;
        }

        50% {
            transform: scale(1.18);
            opacity: 0.72;
        }
    }

    /* ---------------------------------------------------------
       NAVBAR
       --------------------------------------------------------- */

    .motion-nav {
        transition:
            background-color 0.4s ease,
            backdrop-filter 0.4s ease,
            box-shadow 0.4s ease,
            border-color 0.4s ease;
    }

    .motion-nav.scrolled {
        background: rgba(5, 12, 28, 0.78);
        backdrop-filter: blur(18px);
        -webkit-backdrop-filter: blur(18px);
        box-shadow:
            0 10px 35px rgba(0, 0, 0, 0.16);
    }

    /* ---------------------------------------------------------
       TEXT SHIMMER
       --------------------------------------------------------- */

    .motion-shimmer {
        background-size: 200% auto;
        animation: textShimmer 5s linear infinite;
    }

    @keyframes textShimmer {
        to {
            background-position: 200% center;
        }
    }

    /* ---------------------------------------------------------
       DECORATIVE BACKGROUND MOTION
       --------------------------------------------------------- */

    .motion-bg {
        animation:
            backgroundDrift 12s ease-in-out infinite alternate;
    }

    @keyframes backgroundDrift {
        0% {
            transform: translate3d(-1%, 0, 0) scale(1);
        }

        100% {
            transform: translate3d(1%, -1%, 0) scale(1.03);
        }
    }

    /* ---------------------------------------------------------
       RIPPLE
       --------------------------------------------------------- */

    .motion-ripple {
        position: absolute;
        border-radius: 9999px;
        pointer-events: none;
        transform: scale(0);
        animation: rippleEffect 0.65s ease-out forwards;
        background: rgba(255, 255, 255, 0.35);
    }

    @keyframes rippleEffect {
        to {
            transform: scale(4);
            opacity: 0;
        }
    }

    /* ---------------------------------------------------------
       MOBILE
       --------------------------------------------------------- */

    @media (max-width: 768px) {
        .motion-float,
        .motion-float-slow {
            animation-duration: 7s;
        }

        .motion-card:hover {
            transform: translateY(-4px);
        }

        .motion-visual:hover {
            transform: scale(1.01);
        }
    }

    /* ---------------------------------------------------------
       REDUCE MOTION ACCESSIBILITY
       --------------------------------------------------------- */

    @media (prefers-reduced-motion: reduce) {
        *,
        *::before,
        *::after {
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            scroll-behavior: auto !important;
            transition-duration: 0.01ms !important;
        }
    }
</style>


<script>
document.addEventListener('DOMContentLoaded', () => {

    /* =========================================================
       SCROLL REVEAL
       ========================================================= */

    const revealElements = document.querySelectorAll(
        'section, .motion-reveal, .motion-left, .motion-right, .motion-stagger'
    );

    revealElements.forEach((element, index) => {

        if (
            element.classList.contains('motion-reveal') ||
            element.classList.contains('motion-left') ||
            element.classList.contains('motion-right') ||
            element.classList.contains('motion-stagger')
        ) {
            return;
        }

        /* Jangan animasikan navbar */
        if (
            element.closest('nav') ||
            element.tagName.toLowerCase() === 'nav'
        ) {
            return;
        }

        element.classList.add('motion-reveal');

        /* Hero langsung terlihat */
        if (index < 2) {
            element.classList.add('motion-visible');
        }
    });


    const observer = new IntersectionObserver(
        (entries, observer) => {

            entries.forEach(entry => {

                if (!entry.isIntersecting) {
                    return;
                }

                entry.target.classList.add('motion-visible');

                observer.unobserve(entry.target);
            });

        },
        {
            threshold: 0.12,
            rootMargin: '0px 0px -70px 0px'
        }
    );


    document
        .querySelectorAll('.motion-reveal, .motion-left, .motion-right, .motion-stagger')
        .forEach(element => observer.observe(element));


    /* =========================================================
       AUTO ANIMATE CARDS
       ========================================================= */

    const cards = document.querySelectorAll(
        '[class*="rounded-xl"], [class*="rounded-2xl"], [class*="rounded-lg"]'
    );

    cards.forEach(card => {

        if (
            card.closest('nav') ||
            card.closest('header') ||
            card.classList.contains('motion-button')
        ) {
            return;
        }

        card.classList.add('motion-card');
    });


    /* =========================================================
       BUTTON ANIMATION
       ========================================================= */

    const buttons = document.querySelectorAll(
        'a[href], button'
    );

    buttons.forEach(button => {

        button.classList.add('motion-button');

        button.addEventListener('click', function(event) {

            const rect = this.getBoundingClientRect();

            const ripple = document.createElement('span');

            ripple.className = 'motion-ripple';

            const size = Math.max(
                rect.width,
                rect.height
            );

            ripple.style.width = `${size}px`;
            ripple.style.height = `${size}px`;

            ripple.style.left =
                `${event.clientX - rect.left - size / 2}px`;

            ripple.style.top =
                `${event.clientY - rect.top - size / 2}px`;

            this.appendChild(ripple);

            setTimeout(() => {
                ripple.remove();
            }, 700);
        });
    });


    /* =========================================================
       NAVBAR SCROLL EFFECT
       ========================================================= */

    const nav =
        document.querySelector('nav');

    if (nav) {

        nav.classList.add('motion-nav');

        const updateNav = () => {

            if (window.scrollY > 40) {
                nav.classList.add('scrolled');
            } else {
                nav.classList.remove('scrolled');
            }
        };

        updateNav();

        window.addEventListener(
            'scroll',
            updateNav,
            { passive: true }
        );
    }


    /* =========================================================
       PARALLAX HERO
       ========================================================= */

    const heroVisuals = document.querySelectorAll(
        '.motion-visual'
    );

    window.addEventListener(
        'scroll',
        () => {

            const scrollY = window.scrollY;

            heroVisuals.forEach((element, index) => {

                if (scrollY > window.innerHeight) {
                    return;
                }

                const movement =
                    scrollY * (0.035 + index * 0.01);

                element.style.transform =
                    `translateY(${movement}px)`;
            });

        },
        { passive: true }
    );


    /* =========================================================
       MOUSE PARALLAX
       ========================================================= */

    const hero =
        document.querySelector('section');

    if (hero && window.innerWidth > 900) {

        hero.addEventListener('mousemove', event => {

            const rect =
                hero.getBoundingClientRect();

            const x =
                (event.clientX - rect.left) /
                rect.width -
                0.5;

            const y =
                (event.clientY - rect.top) /
                rect.height -
                0.5;

            const visual =
                hero.querySelector('.motion-visual');

            if (!visual) {
                return;
            }

            visual.style.transform =
                `translate(${x * 8}px, ${y * 8}px)`;
        });

        hero.addEventListener('mouseleave', () => {

            const visual =
                hero.querySelector('.motion-visual');

            if (visual) {
                visual.style.transform =
                    'translate(0, 0)';
            }
        });
    }


    /* =========================================================
       AUTOMATIC FLOATING ELEMENTS
       ========================================================= */

    const visualCandidates = document.querySelectorAll(
        'svg, [class*="chart"], [class*="graph"]'
    );

    visualCandidates.forEach((element, index) => {

        if (index % 3 === 0) {
            element.classList.add('motion-float');
        }
    });


    /* =========================================================
       ACTIVE LINK SMOOTH SCROLL
       ========================================================= */

    document
        .querySelectorAll('a[href^="#"]')
        .forEach(link => {

            link.addEventListener('click', event => {

                const targetId =
                    link.getAttribute('href');

                if (
                    !targetId ||
                    targetId === '#'
                ) {
                    return;
                }

                const target =
                    document.querySelector(targetId);

                if (!target) {
                    return;
                }

                event.preventDefault();

                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            });
        });


    /* =========================================================
       ADDITIONAL WATER-LIKE MOVEMENT
       ========================================================= */

    const textElements =
        document.querySelectorAll(
            'h1, h2'
        );

    textElements.forEach((element, index) => {

        if (index === 0) {
            element.classList.add('motion-shimmer');
        }
    });


    /* =========================================================
       PAGE READY
       ========================================================= */

    document.documentElement.classList.add(
        'motion-ready'
    );

});
</script>