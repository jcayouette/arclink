import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Production Ready',
    Svg: require('@site/static/img/undraw_connected-world.svg').default,
    description: (
      <>
        Enterprise-grade Kubernetes deployment for OpenTAK Server. Automated setup,
        persistent storage, and fast deployment on ARM64 and AMD64 platforms.
      </>
    ),
  },
  {
    title: 'Built for the Edge',
    Svg: require('@site/static/img/undraw_server-cluster.svg').default,
    description: (
      <>
        Optimized for resource-constrained environments. Deploy on Raspberry Pi clusters,
        edge servers, or mobile hardware. Maintains operation when infrastructure fails.
      </>
    ),
  },
  {
    title: 'Always-On Position Awareness',
    Svg: require('@site/static/img/undraw_map-dark.svg').default,
    description: (
      <>
        Keep loved ones informed of your location during backcountry adventures. Real-time position tracking via LoRa mesh and APRS beacons ensures family can monitor your safety even when you&apos;re beyond 
        cell coverage.
      </>
    ),
  },
];

function Feature({title, Svg, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
